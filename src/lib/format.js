// ============================================================
// format.js — Helper format & periode (sumber tunggal)
// ============================================================
// Mengganti duplikasi formatRupiah/getCurrentPeriod/getPeriodLabel/
// getRecentPeriods yang sebelumnya disalin di Payroll, IncentiveCalc,
// Kpi, dan Okrs.

// Nama bulan Indonesia (panjang & pendek)
export const MONTHS_ID_LONG = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
export const MONTHS_ID_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/**
 * Format angka sebagai Rupiah.
 * @param {number|null} n
 * @returns {string} 'Rp 1.234.567' atau '-' bila null/NaN
 */
export function formatRupiah(n) {
  if (n == null || isNaN(n)) return '-';
  return 'Rp ' + Number(n).toLocaleString('id-ID');
}

/**
 * Periode berjalan dalam format 'YYYY-MM'.
 * @returns {string}
 */
export function getCurrentPeriod() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Label periode 'YYYY-MM' → 'Januari 2026'. Bila tidak valid → '-'.
 * @param {string} period
 * @returns {string}
 */
export function getPeriodLabel(period) {
  if (!period) return '-';
  const [y, m] = period.split('-');
  return `${MONTHS_ID_LONG[parseInt(m) - 1] || m} ${y}`;
}

/**
 * N periode terakhir (terbaru dulu) untuk filter dropdown.
 * @param {number} count
 * @returns {Array<{id: string, label: string}>} id 'YYYY-MM', label 'Sep 2026'
 */
export function getRecentPeriods(count = 6) {
  const periods = [];
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
