# combine-all.ps1 — Gabung semua SQL jadi FINAL_DEPLOY.sql
$files = @(
  "supabase\migrations\000_pgcrypto.sql",
  "supabase\migrations\CLEAN.sql",
  "supabase\migrations\017_otp_functions.sql",
  "supabase\migrations\018_new_25_tables.sql",
  "supabase\migrations\019_missing_rpc.sql",
  "supabase\migrations\020_fix_login_password.sql",
  "supabase\migrations\021_admin_fix.sql",
  "supabase\migrations\022_ui_fixes.sql",
  "supabase\migrations\023_fix_payroll_benefit.sql",
  "supabase\migrations\024_fix_ringkasan.sql",
  "supabase\migrations\025_okr_survey_asset_offboard.sql"
)

$header = @"
-- ============================================================
-- FINAL_DEPLOY.sql — insightWOS v3.0
-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
-- Total tables: ~88 | Total RPC: ~220+
-- Run ini di Supabase SQL Editor untuk fresh install
-- ============================================================

"@

$combined = $header
foreach ($f in $files) {
  if (Test-Path $f) {
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if ($content) {
      $combined += "`n-- ============================================================`n"
      $combined += "-- FILE: $f`n"
      $combined += "-- ============================================================`n`n"
      $combined += $content + "`n"
      Write-Host "✅ Added: $f"
    }
  } else {
    Write-Host "⚠️  Skip: $f (not found)"
  }
}

$combined | Out-File -FilePath "FINAL_DEPLOY.sql" -Encoding UTF8
Write-Host "`n🏁 FINAL_DEPLOY.sql generated! ($($files.Count) files combined)"
