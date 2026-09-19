#!/usr/bin/env node
/**
 * scripts/safe-file-writer.ts — SATU-SATUNYA jalur tulis berkas teks untuk tooling agent.
 *
 * Kenapa berkas ini ada (jangan dihapus): append ke `agentsLogs.md` lewat
 * `echo "..." >>` di PowerShell pernah menghasilkan berkas dengan NULL byte dan
 * encoding rusak. Menulis lewat shell berarti konten melewati quoting shell, code
 * page konsol, dan redirection yang bisa menambah/menghilangkan byte tanpa
 * terlihat. Skrip ini menutup kelas masalah itu:
 *
 *   1. hanya `fs` + encoding UTF-8 eksplisit — tidak ada shell di jalur tulis;
 *   2. NULL byte dibuang dan JUMLAHNYA DILAPORKAN (tidak pernah diam-diam);
 *   3. EOL diseragamkan (default: ikut berkas yang sudah ada) → tidak ada CRLF/LF campur;
 *   4. BOM yang sudah ada dipertahankan, BOM kedua tidak pernah ditambahkan;
 *   5. sesudah menulis, berkas DIBACA ULANG dan dibandingkan dengan yang diminta —
 *      kalau tidak identik atau masih ada NULL byte, keluar dengan error
 *      (gagal berisik, bukan korup diam-diam).
 *
 * Runner: Node >= 24 menjalankan `.ts` native lewat type stripping. Repo ini TIDAK
 * memakai `tsx`/`vite-node` (tidak terpasang, dan `npx` tidak bisa mengambilnya di
 * environment agent). Lihat AGENTS.md §3.11 (TypeScript only) dan §6.3 (jebakan CLI Windows).
 *
 * Pemakaian:
 *   node scripts/safe-file-writer.ts --file notes.md --content "halo" --mode append
 *   node scripts/safe-file-writer.ts --file notes.md --content-file isi.md --mode overwrite
 *   node scripts/safe-file-writer.ts --file notes.md --content-file isi.md --mode overwrite --eol crlf
 *
 * Untuk konten panjang/multibaris SELALU pakai `--content-file`. Argumen CLI melewati
 * command line OS yang punya batas panjang dan bisa merusak UTF-8 — itu justru akar
 * masalah yang skrip ini selesaikan.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

export type WriteMode = 'append' | 'overwrite';
export type EolStyle = 'crlf' | 'lf' | 'preserve';

export interface WriteOptions {
  /** `append` menambah di akhir, `overwrite` mengganti seluruh isi. Default `append`. */
  mode?: WriteMode;
  /**
   * IZIN EKSPLISIT menimpa berkas yang sudah mengandung NULL byte. Default `false`:
   * berkas rusak biasanya bukti yang perlu ditelusuri, jadi jangan pernah ditimpa
   * tanpa sengaja. Hanya perkakas PERBAIKAN (mis. `repair-text-encoding.ts`) yang
   * boleh menyalakannya, dan wajib menyertakan `corruptReason`.
   */
  allowOverwritingCorrupt?: boolean;
  /** Alasan (wajib bila `allowOverwritingCorrupt`) — dicetak sebagai peringatan. */
  corruptReason?: string;
  /**
   * `crlf` | `lf` memaksa gaya EOL; `preserve`/tidak diisi = ikut berkas yang ada,
   * dan kalau berkas belum ada ikut gaya konten yang dikirim.
   */
  eol?: EolStyle;
}

export interface WriteReport {
  file: string;
  mode: WriteMode;
  eol: Exclude<EolStyle, 'preserve'>;
  created: boolean;
  bytesBefore: number;
  bytesAfter: number;
  bytesWritten: number;
  nullBytesStripped: number;
  bomPreserved: boolean;
  /** Jumlah BOM berlebih di awal berkas yang dirapikan (0 = tidak ada lipatan). */
  bomsCollapsed: number;
  lastLine: string;
}

/** Buang NULL byte (penyebab utama berkas "rusak" dari redirection shell). */
export function stripNullBytes(text: string): { text: string; stripped: number } {
  const stripped = text.split('\u0000').length - 1;
  return { text: stripped === 0 ? text : text.replace(/\u0000/g, ''), stripped };
}

/** Tebak gaya EOL dominan; berkas campuran CRLF/LF dihitung dan yang menang dipilih. */
export function detectEol(text: string): Exclude<EolStyle, 'preserve'> {
  const totalLf = (text.match(/\n/g) ?? []).length;
  const crlf = (text.match(/\r\n/g) ?? []).length;
  const bareLf = totalLf - crlf;
  return crlf > 0 && crlf >= bareLf ? 'crlf' : 'lf';
}

function normalizeEol(text: string, eol: Exclude<EolStyle, 'preserve'>): string {
  const lf = text.replace(/\r\n/g, '\n');
  return eol === 'crlf' ? lf.replace(/\n/g, '\r\n') : lf;
}

/**
 * Tulis berkas teks dengan jaminan: UTF-8 ketat, tanpa NULL byte, EOL seragam,
 * BOM tidak berlipat, dan hasilnya diverifikasi dengan baca-ulang.
 *
 * Dipakai langsung oleh skrip lain (mis. `run-parallel-checks.ts`) supaya SEMUA
 * tulisan berkas melewati satu implementasi — bukan hanya jalur CLI-nya.
 */
export function writeFileSafe(file: string, content: string, options: WriteOptions = {}): WriteReport {
  const mode: WriteMode = options.mode ?? 'append';
  if (mode !== 'append' && mode !== 'overwrite') {
    throw new Error(`mode tidak dikenal: ${String(mode)} (pakai 'append' atau 'overwrite')`);
  }
  if (typeof content !== 'string') {
    throw new Error('konten harus berupa string');
  }

  const target = path.resolve(file);
  const dir = path.dirname(target);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const created = !fs.existsSync(target);
  const beforeRaw = created ? '' : fs.readFileSync(target, 'utf8');
  if (beforeRaw.includes('\u0000')) {
    if (options.allowOverwritingCorrupt !== true) {
      throw new Error(
        `berkas tujuan sudah mengandung NULL byte: ${target} — perbaiki dulu secara manual, ` +
          'jangan ditimpa (bisa jadi bukti korupsi yang perlu ditelusuri). ' +
          'Perkakas perbaikan harus memakai { allowOverwritingCorrupt: true, corruptReason: "…" }.',
      );
    }
    console.error(
      `PERINGATAN: menimpa berkas yang mengandung NULL byte (${target}) — ` +
        `alasan: ${options.corruptReason ?? 'TIDAK DISEBUTKAN (itu sendiri sebuah bug)'}`,
    );
  }
  // BOM: pertahankan paling banyak SATU di awal berkas. Berkas yang ter-append dari tool
  // lain pernah berakhir dengan BOM BERLIPAT (`agentsLogs.md` sempat diawali `efbbbfefbbbf`);
  // kalau hanya BOM pertama yang dibuang, lipatan itu ikut dipelihara selamanya. Jadi semua
  // BOM di awal dibuang, lalu satu dipasang kembali — dan jumlah lipatan dilaporkan.
  const leadingBoms = beforeRaw.match(/^\uFEFF+/)?.[0].length ?? 0;
  const hadBom = leadingBoms > 0;
  const before = hadBom ? beforeRaw.slice(leadingBoms) : beforeRaw;

  const { text: cleanContent, stripped: nullBytesStripped } = stripNullBytes(content);
  const requestedEol = options.eol ?? 'preserve';
  const eol: Exclude<EolStyle, 'preserve'> =
    requestedEol === 'preserve'
      ? before.length > 0
        ? detectEol(before)
        : detectEol(cleanContent)
      : requestedEol;

  let body = before;
  const incoming = normalizeEol(cleanContent, eol);
  // `eol` adalah NAMA gaya ('crlf'/'lf'); urutan newline sebenarnya adalah `nl`.
  // Jangan tertukar: memakai `eol` di sini menyisipkan teks "lf" ke dalam berkas.
  const nl = eol === 'crlf' ? '\r\n' : '\n';
  if (mode === 'append') {
    // Jangan pernah menyambung baris: kalau berkas lama tidak diakhiri newline,
    // tambahkan dulu satu — ini persis kelas kerusakan yang ingin dihindari.
    if (body.length > 0 && !body.endsWith(nl)) {
      body = body.endsWith('\n') ? body + nl.slice(-1) : body + nl;
    }
    body += incoming;
  } else {
    body = incoming;
  }

  const finalText = (hadBom ? '\uFEFF' : '') + body;
  fs.writeFileSync(target, finalText, { encoding: 'utf8', flag: 'w' });

  // Verifikasi baca-ulang: satu-satunya bukti bahwa yang tertulis = yang diminta.
  const readBack = fs.readFileSync(target, 'utf8');
  if (readBack.includes('\u0000')) {
    throw new Error(`verifikasi gagal: NULL byte tertulis ke ${target}`);
  }
  if (readBack !== finalText) {
    throw new Error(
      `verifikasi gagal: isi ${target} tidak identik dengan yang diminta ` +
        `(diminta ${Buffer.byteLength(finalText, 'utf8')} byte, terbaca ${Buffer.byteLength(readBack, 'utf8')} byte)`,
    );
  }
  // Yang diperiksa hanya "BOM TIDAK BERGANTUNG": berkas diawali dua BOM berarti kita
  // menambahkan BOM ke berkas yang sudah punya. BOM nyasar di TENGAH berkas (pernah
  // terjadi di `agentsLogs.md` akibat append dari tool berbeda) bukan urusan jalur tulis
  // ini — memeriksanya di sini menghasilkan kegagalan palsu setelah tulisan berhasil.
  if (readBack.startsWith('\uFEFF\uFEFF')) {
    throw new Error(`verifikasi gagal: BOM berlipat di awal ${target}`);
  }

  const lines = finalText.split(nl).filter((l) => l.length > 0);
  return {
    file: target,
    mode,
    eol,
    created,
    bytesBefore: Buffer.byteLength(beforeRaw, 'utf8'),
    bytesAfter: Buffer.byteLength(finalText, 'utf8'),
    bytesWritten: Buffer.byteLength(finalText, 'utf8') - Buffer.byteLength(beforeRaw, 'utf8'),
    nullBytesStripped,
    bomPreserved: hadBom,
    bomsCollapsed: Math.max(0, leadingBoms - 1),
    lastLine: (lines.at(-1) ?? '').slice(0, 120),
  };
}

const USAGE = `safe-file-writer — tulis berkas teks UTF-8 dengan aman (tanpa shell, tanpa NULL byte)

Pemakaian:
  node scripts/safe-file-writer.ts --file <path> --content <string> --mode <append|overwrite>
  node scripts/safe-file-writer.ts --file <path> --content-file <path> --mode <append|overwrite>

Opsi:
  --file <path>          wajib — berkas tujuan (relatif ke cwd atau absolut)
  --content <string>     isi yang ditulis (untuk teks pendek)
  --content-file <path>  isi dibaca dari berkas lain (WAJIB untuk konten panjang/multibaris)
  --mode <append|overwrite>  wajib
  --eol <crlf|lf|preserve>   default preserve (ikut berkas yang sudah ada)
  --json                 cetak laporan sebagai JSON
  --quiet                tidak mencetak apa pun selain error
  --help                 tampilkan bantuan ini

Exit code: 0 sukses, 1 argumen salah, 2 gagal menulis/verifikasi.`;

interface CliArgs {
  file?: string;
  content?: string;
  contentFile?: string;
  mode?: string;
  eol?: string;
  json: boolean;
  quiet: boolean;
  help: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = { json: false, quiet: false, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    const next = (): string => {
      const value = argv[i + 1];
      if (value === undefined) throw new Error(`opsi ${token} butuh nilai`);
      i += 1;
      return value;
    };
    switch (token) {
      case '--file':
        args.file = next();
        break;
      case '--content':
        args.content = next();
        break;
      case '--content-file':
        args.contentFile = next();
        break;
      case '--mode':
        args.mode = next();
        break;
      case '--eol':
        args.eol = next();
        break;
      case '--json':
        args.json = true;
        break;
      case '--quiet':
        args.quiet = true;
        break;
      case '--help':
      case '-h':
        args.help = true;
        break;
      default:
        throw new Error(`opsi tidak dikenal: ${token}`);
    }
  }
  return args;
}

function main(argv: string[]): number {
  let args: CliArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    console.error(`ARGUMEN SALAH: ${(error as Error).message}\n\n${USAGE}`);
    return 1;
  }

  if (args.help) {
    console.log(USAGE);
    return 0;
  }

  const problems: string[] = [];
  if (!args.file) problems.push('--file wajib');
  if (!args.mode) problems.push('--mode wajib');
  if (!args.content && !args.contentFile) problems.push('--content atau --content-file wajib');
  if (args.content !== undefined && args.contentFile !== undefined) {
    problems.push('--content dan --content-file tidak boleh dipakai bersamaan');
  }
  if (args.mode !== undefined && args.mode !== 'append' && args.mode !== 'overwrite') {
    problems.push(`--mode harus 'append' atau 'overwrite' (dapat: ${args.mode})`);
  }
  if (args.eol !== undefined && args.eol !== 'crlf' && args.eol !== 'lf' && args.eol !== 'preserve') {
    problems.push(`--eol harus 'crlf'|'lf'|'preserve' (dapat: ${args.eol})`);
  }
  if (problems.length > 0) {
    console.error(`ARGUMEN SALAH:\n  - ${problems.join('\n  - ')}\n\n${USAGE}`);
    return 1;
  }

  try {
    const content =
      args.contentFile !== undefined
        ? fs.readFileSync(path.resolve(args.contentFile), 'utf8')
        : (args.content as string);
    const report = writeFileSafe(args.file as string, content, {
      mode: args.mode as WriteMode,
      eol: args.eol as EolStyle | undefined,
    });
    if (args.json) {
      console.log(JSON.stringify(report));
    } else if (!args.quiet) {
      const verb = report.mode === 'append' ? 'ditambahkan' : 'ditimpa';
      const nul =
        report.nullBytesStripped > 0
          ? `  ⚠ ${report.nullBytesStripped} NULL byte DIBUANG (sumber konten perlu diperiksa)`
          : '';
      const bom = report.bomsCollapsed > 0 ? `  ⚠ ${report.bomsCollapsed} BOM berlipat dirapikan` : '';
      console.log(
        `OK ${report.file}\n  mode=${report.mode} eol=${report.eol} ` +
          `${report.created ? 'dibuat' : verb} ${report.bytesWritten} byte ` +
          `(${report.bytesBefore} → ${report.bytesAfter})${nul}${bom}`,
      );
    }
    return 0;
  } catch (error) {
    console.error(`GAGAL: ${(error as Error).message}`);
    return 2;
  }
}

// Hanya jalankan CLI bila dipanggil sebagai program, bukan saat di-import skrip lain.
const entry = process.argv[1];
const invokedAsCli = entry !== undefined && path.resolve(entry) === path.resolve(fileURLToPath(import.meta.url));
if (invokedAsCli) {
  process.exitCode = main(process.argv.slice(2));
}
