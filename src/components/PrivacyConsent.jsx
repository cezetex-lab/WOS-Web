import React, { useState, useEffect } from 'react';

const CONSENT_KEY = 'wos_privacy_consent';

export function usePrivacyConsent() {
  const [consented, setConsented] = useState(() => {
    try {
      return localStorage.getItem(CONSENT_KEY) === 'true';
    } catch { return false; }
  });

  const accept = () => {
    localStorage.setItem(CONSENT_KEY, 'true');
    setConsented(true);
  };

  return { consented, accept };
}

export default function PrivacyConsent({ onAccept }) {
  const [show, setShow] = useState(false);
  const [showDetails, setShowDetails] = useState(false);

  useEffect(() => {
    try {
      if (localStorage.getItem(CONSENT_KEY) !== 'true') {
        setShow(true);
      }
    } catch { setShow(true); }
  }, []);

  if (!show) return null;

  const handleAccept = () => {
    localStorage.setItem(CONSENT_KEY, 'true');
    setShow(false);
    onAccept?.();
  };

  return (
    <div className="fixed inset-0 z-[9999] bg-black/70 backdrop-blur-sm flex items-end sm:items-center justify-center p-4" role="dialog" aria-modal="true" aria-label="Persetujuan Privasi">
      <div className="bg-slate-800 border border-slate-600 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-4">
        {/* Header */}
        <div className="flex items-start gap-3">
          <span className="text-3xl">🛡️</span>
          <div>
            <h2 className="text-lg font-bold text-white">Perlindungan Data Pribadi</h2>
            <p className="text-xs text-slate-400 mt-1">Sesuai UU No. 27/2022 (UU PDP) & GDPR</p>
          </div>
        </div>

        {/* Content */}
        <div className="text-sm text-slate-300 space-y-2">
          <p>
            insightWOS mengumpulkan dan memproses data pribadi Anda untuk keperluan:
          </p>
          <ul className="list-disc list-inside space-y-1 text-slate-400">
            <li>Pengelolaan HR (kehadiran, payroll, performa)</li>
            <li>Komunikasi internal perusahaan</li>
            <li>Kepatuhan regulasi ketenagakerjaan</li>
          </ul>

          {/* Details toggle */}
          <button
            onClick={() => setShowDetails(!showDetails)}
            className="text-teal-400 hover:text-teal-300 text-xs font-medium transition-colors"
            aria-expanded={showDetails}
          >
            {showDetails ? '▼ Sembunyikan detail' : '▶ Lihat detail kebijakan privasi'}
          </button>

          {showDetails && (
            <div className="bg-slate-900/50 rounded-lg p-3 text-xs text-slate-400 space-y-2 border border-slate-700">
              <p><strong className="text-slate-300">Hak Anda:</strong></p>
              <ul className="list-disc list-inside space-y-1">
                <li>Akses data pribadi yang kami simpan</li>
                <li>Memperbaiki data yang tidak akurat</li>
                <li>Meminta penghapusan data (dengan batasan hukum)</li>
                <li>Menolak pemrosesan data tertentu</li>
                <li>Meminta portabilitas data</li>
              </ul>
              <p><strong className="text-slate-300">Penyimpanan:</strong> Data disimpan di Supabase Cloud (AWS ap-southeast-1). Tidak ada transfer data ke negara ketiga tanpa persetujuan.</p>
              <p><strong className="text-slate-300">Keamanan:</strong> Enkripsi data saat transit (TLS 1.3) dan saat disimpan (AES-256). Akses dibatasi berdasarkan role (RLS).</p>
              <p><strong className="text-slate-300">Kontak DPO:</strong> dpo@insightwos.com — untuk pertanyaan atau permintaan terkait data pribadi.</p>
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-2 pt-2">
          <button
            onClick={handleAccept}
            className="flex-1 bg-teal-500 hover:bg-teal-400 text-white font-semibold py-3 px-4 rounded-xl transition-colors"
            autoFocus
          >
            ✅ Saya Setuju
          </button>
          <button
            onClick={() => window.location.href = 'https://insightwos.vercel.app'}
            className="flex-1 bg-slate-700 hover:bg-slate-600 text-slate-300 font-semibold py-3 px-4 rounded-xl transition-colors"
          >
            ❌ Tidak Setuju
          </button>
        </div>

        <p className="text-[11px] text-slate-500 text-center">
          Dengan mengklik "Saya Setuju", Anda menyetujui pemrosesan data sesuai Kebijakan Privasi kami.
        </p>
      </div>
    </div>
  );
}
