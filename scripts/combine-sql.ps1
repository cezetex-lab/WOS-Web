# combine-sql.ps1 — Gabung semua SQL jadi 1 file
# Run: .\combine-sql.ps1
# Output: FINAL_DEPLOY.sql

$files = @(
    "supabase\migrations\000_pgcrypto.sql",
    "supabase\migrations\001_init.sql",
    "supabase\migrations\018_new_25_tables.sql",
    "supabase\migrations\CLEAN.sql",
    "supabase\migrations\017_otp_functions.sql",
    "supabase\migrations\020_fix_login_password.sql",
    "supabase\migrations\021_admin_fix.sql",
    "supabase\migrations\022_ui_fixes.sql",
    "supabase\migrations\023_fix_payroll_benefit.sql"
)

$output = "FINAL_DEPLOY.sql"
$header = @"
-- ================================================================
-- insightWOS v3.0 — FINAL DEPLOY SQL
-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
-- Run this ONE file in Supabase SQL Editor → Click "Run"
-- ================================================================

"@

Set-Content -Path $output -Value $header -Encoding UTF8

foreach ($file in $files) {
    if (Test-Path $file) {
        Add-Content -Path $output -Value "`n-- ================================================================" -Encoding UTF8
        Add-Content -Path $output -Value "-- SECTION: $file" -Encoding UTF8
        Add-Content -Path $output -Value "-- ================================================================`n" -Encoding UTF8
        Get-Content $file | Add-Content -Path $output -Encoding UTF8
        Write-Host "OK: $file"
    } else {
        Write-Host "SKIP: $file (not found)"
    }
}

$footer = @"

-- ================================================================
-- DEPLOY SELESAI!
-- Sekarang test login: NRP001 + NIK 3201234567890001 + Password123
-- ================================================================
"@
Add-Content -Path $output -Value $footer -Encoding UTF8

Write-Host "`nDONE! File: $output"
Write-Host "Paste isi file ini ke Supabase SQL Editor → Klik Run"
