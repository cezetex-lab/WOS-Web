// EmergencyProcedures.jsx — Mining Emergency Procedures & Contacts
import { useState } from 'react';
import { GlassCard, SectionHeader } from '@/lib/design-system';

const PROCEDURES = [
  { icon: '🔥', title: 'Kebakaran', steps: ['1. Matikan mesin & alarm', '2. Hubungi Command Center: ext 100', '3. Gunakan APAR terdekat', '4. Evakuasi ke assembly point'] },
  { icon: '🏔️', title: 'Longsor / Ground Movement', steps: ['1. Jauhi area longsor', '2. Hubungi control room: ext 110', '3. Tandai area berbahaya', '4. Tunggu instruktur K3'] },
  { icon: '💨', title: 'Gas Berbahaya / Debuan', steps: ['1. Pakai respiratory mask', '2. Jauhi area', '3. Hubungi medis: ext 120', '4. Ventilasi area jika aman'] },
  { icon: '🌊', title: 'Banjir / Water Ingress', steps: ['1. Matikan semua pompa listrik', '2. Evakuasi ke titik tinggi', '3. Hubungi: ext 110', '4. Jangan coba menyeberang air deras'] },
  { icon: '⚡', title: 'Kecelakaan Listrik', steps: ['1. Jangan sentuh korban', '2. Matikan MCB terdekat', '3. Hubungi medis: ext 120', '4. CPR jika perlu'] },
  { icon: '💥', title: 'Ledakan / Blast Incident', steps: ['1. Berlindung di tempat aman', '2. Hubungi command center: ext 100', '3. Evakuasi entire zone', '4. Tunggu all-clear signal'] },
];

const CONTACTS = [
  { name: 'Command Center', phone: 'ext 100 / +62-812-xxxx-100', available: '24/7', icon: '🏢' },
  { name: 'K3 Safety Officer', phone: 'ext 110 / +62-812-xxxx-110', available: '24/7', icon: '🛡️' },
  { name: 'Medical / Puskesmas', phone: 'ext 120 / +62-812-xxxx-120', available: '24/7', icon: '🚑' },
  { name: 'Fire Brigade', phone: 'ext 119 / +62-812-xxxx-119', available: '24/7', icon: '🚒' },
  { name: 'HR Manager', phone: '+62-812-xxxx-0001', available: 'Office Hours', icon: '👤' },
  { name: 'Environmental Officer', phone: 'ext 130', available: 'Office Hours', icon: '🌿' },
];

export default function EmergencyProcedures() {
  const [expanded, setExpanded] = useState(null);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🚨 Emergency Procedures</h1>
        <p className="text-xs text-slate-400 mb-4">Prosedur darurat & kontak penting tambang</p>

        {/* SOS Banner */}
        <div className="bg-red-600/20 border-2 border-red-500 rounded-2xl p-4 mb-4 text-center">
          <div className="text-3xl mb-2">🆘</div>
          <div className="text-lg font-bold text-red-400">DARURAT? HUBUNGI SEGERA</div>
          <a href="tel:+62812xxxx100" className="inline-block mt-2 px-6 py-2 bg-red-500 text-white rounded-lg font-bold text-lg">📞 ext 100</a>
        </div>

        <SectionHeader title="📋 Prosedur Darurat" />
        <div className="space-y-2 mb-6">
          {PROCEDURES.map((p, i) => (
            <GlassCard key={i} className="p-3 cursor-pointer" onClick={() => setExpanded(expanded === i ? null : i)}>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xl">{p.icon}</span>
                  <span className="text-sm font-bold text-white">{p.title}</span>
                </div>
                <span className="text-slate-400 text-sm">{expanded === i ? '▲' : '▼'}</span>
              </div>
              {expanded === i && (
                <div className="mt-3 space-y-1">
                  {p.steps.map((s, j) => (
                    <div key={j} className="text-xs text-slate-300 bg-slate-800/40 rounded-lg px-3 py-1.5">{s}</div>
                  ))}
                </div>
              )}
            </GlassCard>
          ))}
        </div>

        <SectionHeader title="📞 Kontak Darurat" />
        <div className="space-y-2">
          {CONTACTS.map((c, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xl">{c.icon}</span>
                  <div>
                    <div className="text-sm font-semibold text-white">{c.name}</div>
                    <div className="text-[10px] text-slate-500">{c.available}</div>
                  </div>
                </div>
                <a href={`tel:${c.phone}`} className="px-3 py-1 bg-teal-500/20 text-teal-400 rounded-lg text-xs font-bold hover:bg-teal-500/30">📞 Hubungi</a>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
