#!/usr/bin/env node
/**
 * run_171.mjs — Dollar-quote-aware SQL runner
 *
 * Reads any .sql file, splits statements properly (respecting $function$,
 * $$, and $tag$ dollar-quoting), and executes each one against PostgreSQL.
 *
 * DB URL is read from .env.local (DATABASE_URL=) by default.
 * Optionally override via first CLI argument (not recommended in logged terminals).
 *
 * Usage:
 *   node run_171.mjs [SQL_FILE]
 *   node run_171.mjs --db-url "postgresql://..." [SQL_FILE]
 *
 * Examples:
 *   node run_171.mjs                          # .env.local → 171_restore_db_only_functions.sql
 *   node run_171.mjs 168_fix_p0_p1.sql        # .env.local → specified file
 *
 * Requires: npm install pg
 */

import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

// ── 1. Load DB URL from .env.local (never from positional argv to avoid log leaks) ──
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, "../../.env.local");

let connStr;
try {
  const envContent = readFileSync(envPath, "utf-8");
  const match = envContent.match(/^DATABASE_URL\s*=\s*(.+)$/m);
  if (match) connStr = match[1].trim().replace(/^["']|["']$/g, "");
} catch { /* .env.local not found or unreadable */ }

// Allow explicit --db-url flag as override (for CI/special cases)
const dbUrlIdx = process.argv.indexOf("--db-url");
if (dbUrlIdx !== -1 && process.argv[dbUrlIdx + 1]) {
  connStr = process.argv[dbUrlIdx + 1];
}

if (!connStr) {
  console.error("ERROR: DATABASE_URL not found.");
  console.error("  Set it in .env.local or pass --db-url \"postgresql://...\"");
  process.exit(1);
}

// SQL file: first non-flag argument, or default to 171_restore_db_only_functions.sql
const sqlFileArg = process.argv.slice(2).find(a => !a.startsWith("--") && a !== connStr);

// ── 2. Dollar-quote-aware splitter ───────────────────────────────────
function splitStatements(sql) {
  const stmts = [];
  let i = 0;
  const len = sql.length;

  while (i < len) {
    // Skip whitespace
    while (i < len && /\s/.test(sql[i])) i++;
    if (i >= len) break;

    // Skip line comments
    if (sql[i] === "-" && sql[i + 1] === "-") {
      while (i < len && sql[i] !== "\n") i++;
      continue;
    }

    // Skip block comments
    if (sql[i] === "/" && sql[i + 1] === "*") {
      i += 2;
      while (i < len && !(sql[i] === "*" && sql[i + 1] === "/")) i++;
      i += 2;
      continue;
    }

    // Start of a real statement — find its end
    let depth = 0;
    let dollarTag = null;
    let stmtStart = i;

    while (i < len) {
      // Dollar-quote: $tag$ where tag is empty ($$) or starts with letter/_
      if (sql.charCodeAt(i) === 36) {
        let j = i + 1;
        const fc = j < len ? sql.charCodeAt(j) : 0;
        // Valid: $$ (empty) or $letter/_...
        // Reject: $digit... (bcrypt $2a$, $2b$, etc.)
        if (fc === 36 || (fc >= 65 && fc <= 90) || (fc >= 97 && fc <= 122) || fc === 95) {
          while (j < len && sql.charCodeAt(j) !== 36) j++;
          if (j < len) {
            const tag = sql.slice(i, j + 1);
            if (dollarTag === null) {
              // Opening
              dollarTag = tag;
              depth++;
              i = j + 1;
              continue;
            } else if (dollarTag === tag) {
              // Closing
              depth--;
              dollarTag = null;
              i = j + 1;
              if (depth === 0) {
                // Check if trailing clauses follow (LANGUAGE, SECURITY, SET, etc.)
                let k = i;
                while (k < len && /\s/.test(sql[k])) k++;
                if (k < len && /^(?:LANGUAGE|SECURITY|SET|STABLE|VOLATILE|IMMUTABLE|COST|ROWS|SUPPORT|PARALLEL|LEAKPROOF|CALLED|RETURNS|STRICT|WINDOW)\b/i.test(sql.slice(k))) {
                  while (i < len && sql[i] !== ";") i++;
                  if (i < len && sql[i] === ";") i++;
                }
                stmts.push(sql.slice(stmtStart, i).trim());
                break;
              }
              continue;
            }
          }
        }
        i++;
        continue;
      }

      // Top-level semicolon = statement end
      if (depth === 0 && sql[i] === ";") {
        stmts.push(sql.slice(stmtStart, i + 1).trim());
        i++;
        break;
      }

      i++;
    }
  }

  return stmts;
}

// ── 3. Load SQL file ─────────────────────────────────────────────────
const sqlPath = sqlFileArg
  ? (sqlFileArg.includes("/") || sqlFileArg.includes("\\") ? sqlFileArg : join(__dirname, sqlFileArg))
  : join(__dirname, "171_restore_db_only_functions.sql");
const sql = readFileSync(sqlPath, "utf-8");
const stmts = splitStatements(sql);

console.log(`📄 SQL file loaded: ${sqlPath}`);
console.log(`   Total statements: ${stmts.length}`);
console.log();

// ── 4. Connect & execute ALL statements ──────────────────────────────
async function main() {
  let Client;
  try {
    const pg = await import("pg");
    Client = pg.Client;
  } catch {
    console.error("❌ 'pg' not found. Run: npm install pg");
    process.exit(1);
  }

  const client = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });

  try {
    await client.connect();
    console.log("🔌 Connected to database\n");

    let ok = 0, fail = 0;

    for (let idx = 0; idx < stmts.length; idx++) {
      const stmt = stmts[idx];
      const m = stmt.match(/(?:FUNCTION|TABLE|INDEX|TYPE|VIEW|EXTENSION|SCHEMA)\s+(?:IF NOT EXISTS\s+)?(?:public\.)?\s*(\w+)/i)
             || stmt.match(/^(\w+)/);
      const name = m ? m[1] : `#${idx + 1}`;
      const progress = `[${idx + 1}/${stmts.length}]`;

      try {
        await client.query(stmt);
        console.log(`  ✅ ${progress} ${name}`);
        ok++;
      } catch (err) {
        console.error(`  ❌ ${progress} ${name}: ${err.message}`);
        fail++;
      }
    }

    console.log(`\n📊 Result: ${ok} succeeded, ${fail} failed out of ${stmts.length} statements`);
  } finally {
    await client.end();
  }
}

main().catch(err => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
