// Sumber tunggal format & periode (dipakai lintas page; validasi: zod schemas).

// Nama bulan Indonesia (panjang & pendek)
export const MONTHS_ID_LONG = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
export const MONTHS_ID_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/**
 * Format angka sebagai Rupiah.
 * @param n - number or null
 * @returns 'Rp 1.234.567' atau '-' bila null/NaN
 */
export function formatRupiah(n: number | null): string {
  if (n == null || isNaN(n)) return '-';
  return 'Rp ' + Number(n).toLocaleString('id-ID');
}

/**
 * Periode berjalan dalam format 'YYYY-MM'.
 * @returns string
 */
export function getCurrentPeriod(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Label periode 'YYYY-MM' → 'Januari 2026'. Bila tidak valid → '-'.
 * @param period - string period in YYYY-MM format
 * @returns string
 */
export function getPeriodLabel(period: string): string {
  if (!period) return '-';
  const [y, m] = period.split('-');
  return `${MONTHS_ID_LONG[parseInt(m) - 1] || m} ${y}`;
}

/**
 * N periode terakhir (terbaru dulu) untuk filter dropdown.
 * @param count - number of periods to return
 * @returns Array<{id: string, label: string}> id 'YYYY-MM', label 'Sep 2026'
 */
export function getRecentPeriods(count: number = 6): Array<{ id: string; label: string }> {
  const periods: Array<{ id: string; label: string }> = [];
  const now = new Date();
  for (let i = 0; i < count; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    periods.push({
      id: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
      label: `${MONTHS_ID_SHORT[d.getMonth()]} ${d.getFullYear()}`,
    });
  }
  return periods;
}
