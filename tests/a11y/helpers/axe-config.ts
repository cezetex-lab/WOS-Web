/**
 * axe-config.ts — konfigurasi shared untuk scan a11y (FASE 3 Stage 1).
 *
 * Prinsip: rule TIDAK dinonaktifkan tanpa alasan terdokumentasi. Setiap entri
 * di DISABLED_RULES wajib membawa komentar alasannya + kapan harus ditinjau
 * ulang. Tag dipatok pada WCAG 2.0/2.1 level A + AA sesuai target DoD.
 */
import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';

/** Tag yang dipakai SEMUA scan: WCAG 2.0/2.1 level A + AA. */
export const AXE_TAGS = ['wcag2a', 'wcag2aa'] as const;

/**
 * Rule yang dinonaktifkan global. HANYA satu, dengan alasan:
 *
 * - `region`: shell SPA ini men-render drawer/menu + fallback "Memuat modul…"
 *   di luar landmark `<main>`, dan di layout mobile drawer berada di luar
 *   viewport konten — rule ini mendominasi false positive di 4 page sambil
 *   prinsip WCAG 2.4.1 (blok berulang punya bypass) tetap terverifikasi oleh
 *   rule `bypass` yang TETAP AKTIF. Tinjau ulang bila shell direstrukturisasi
 *   (mis. drawer pindah ke dalam landmark).
 */
const DISABLED_RULES = ['region'] as const;

/** Builder Axe dengan konfigurasi standar proyek — pakai ini di semua spec. */
export function createAxeBuilder(page: Page): AxeBuilder {
  return new AxeBuilder({ page })
    .withTags([...AXE_TAGS])
    .disableRules([...DISABLED_RULES]);
}

/** Bentuk hasil analyze() — diekspor agar spec tidak import axe langsung. */
export type AxeResults = Awaited<ReturnType<AxeBuilder['analyze']>>;
export type AxeViolation = AxeResults['violations'][number];

/** Jalankan scan penuh (tags wcag2a/wcag2aa, minus DISABLED_RULES). */
export async function scanA11y(page: Page): Promise<AxeResults> {
  return createAxeBuilder(page).analyze();
}

/** Violation yang wajib nol: impact critical atau serious. */
export function seriousViolations(results: AxeResults): AxeViolation[] {
  return results.violations.filter(
    (v) => v.impact === 'critical' || v.impact === 'serious',
  );
}

/** Ringkasan 1 baris per violation untuk output mentah / pesan assert. */
export function summarize(results: AxeResults): string {
  if (results.violations.length === 0) return '(0 violation)';
  return results.violations
    .map((v) => {
      const nodes = v.nodes.map((n) => n.target.join(' ')).slice(0, 3).join(' | ');
      return `[${v.impact ?? 'unknown'}] ${v.id} (${v.nodes.length} node): ${nodes}`;
    })
    .join('\n  ');
}

/** Settle SPA: tunggu networkidle secara toleran (websocket supabase bisa
 *  menahan networkidle selamanya), lalu jeda kecil untuk render lazy chunk. */
export async function settle(page: Page): Promise<void> {
  // OPS-10: 15s — churn get_branding/token refresh (lihat OPS-11) bisa menyapu
  // jendela idle 8s; 15s memberi ruang tanpa melebihi budget test 20s.
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {
    /* networkidle tidak tercapai (realtime/websocket) — anggap settled */
  });
  await page.waitForTimeout(1500);
}

/** Lampirkan bukti (screenshot + JSON violation) ke testInfo untuk debugging. */
export async function attachAxeReport(
  page: Page,
  testInfo: { attach: (name: string, options: { body: string | Buffer; contentType: string }) => Promise<void> },
  label: string,
  serious: AxeViolation[],
): Promise<void> {
  await testInfo.attach(`${label}-axe-violations.json`, {
    body: JSON.stringify(serious, null, 2),
    contentType: 'application/json',
  });
  await testInfo.attach(`${label}-screenshot.png`, {
    body: await page.screenshot(),
    contentType: 'image/png',
  });
}
