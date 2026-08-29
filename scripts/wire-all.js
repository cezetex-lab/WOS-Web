const fs = require('fs');

// ============================================================
// WORKER PAGE — tambah 12 RPC + display sections
// ============================================================
let w = fs.readFileSync('src/app/worker/page.js', 'utf8');

// 1. State variables baru
const newStates = [
  'const [medical, setMedical] = useState([])',
  'const [overtime, setOvertime] = useState([])',
  'const [ideas, setIdeas] = useState([])',
  'const [trainingCatalog, setTrainingCatalog] = useState([])',
  'const [talentMarket, setTalentMarket] = useState([])',
  'const [contPerf, setContPerf] = useState([])',
  'const [compIntel, setCompIntel] = useState(null)',
  'const [capability, setCapability] = useState([])',
  'const [exitInfo, setExitInfo] = useState(null)',
].join('\n  ');

w = w.replace(
  'const [refreshY, setRefreshY] = useState(0);',
  'const [refreshY, setRefreshY] = useState(0);\n  ' + newStates
);

// 2. RPC calls baru di Promise.all
const newRpcs = `
        rpc('get_worker_medical', { p_nrp: nrp }),
        rpc('get_worker_overtime', { p_nrp: nrp }),
        rpc('list_ideas'),
        rpc('get_training_catalog'),
        rpc('get_talent_marketplace'),
        rpc('get_my_continuous_performance', { p_nrp: nrp }),
        rpc('get_my_compensation_intelligence', { p_nrp: nrp }),
        rpc('get_worker_capability', { p_nrp: nrp }),
        rpc('get_worker_exit', { p_nrp: nrp })`;

w = w.replace(
  "rpc('get_worker_narrative', { p_nrp: nrp })\n      ]);",
  "rpc('get_worker_narrative', { p_nrp: nrp })," + newRpcs + "\n      ]);"
);

// 3. Destructuring baru
const newDestruct = `
      if (med.ok && med.data) setMedical(med.data);
      if (ot.ok && ot.data) setOvertime(ot.data);
      if (ideas.ok && ideas.data) setIdeas(ideas.data);
      if (tCat.ok && tCat.data) setTrainingCatalog(tCat.data);
      if (tMkt.ok && tMkt.data) setTalentMarket(tMkt.data);
      if (cPerf.ok && cPerf.data) setContPerf(cPerf.data);
      if (cIntel.ok) setCompIntel(cIntel);
      if (cap.ok && cap.data) setCapability(cap.data);
      if (ex.ok && ex.data) setExitInfo(ex.data);`;

w = w.replace(
  "const [p, s, a, req, pay, lv, learn, eng, notif, cp, sk, ben, nar] = r;",
  "const [p, s, a, req, pay, lv, learn, eng, notif, cp, sk, ben, nar, med, ot, ideas, tCat, tMkt, cPerf, cIntel, cap, ex] = r;" + newDestruct
);

// 4. Sub-tab tambahan
w = w.replace(
  "activity: [{ id:'request', label:'📋 Request' }, { id:'cuti', label:'🏖️ Cuti' }, { id:'training', label:'📚 Training' }]",
  "activity: [{ id:'request', label:'📋 Request' }, { id:'cuti', label:'🏖️ Cuti' }, { id:'training', label:'📚 Training' }, { id:'overtime', label:'⏰ Lembur' }]"
);
w = w.replace(
  "dev: [{ id:'career', label:'🚀 Career' }, { id:'skills', label:'🎯 Skills' }, { id:'engage', label:'💜 Engagement' }]",
  "dev: [{ id:'career', label:'🚀 Career' }, { id:'skills', label:'🎯 Skills' }, { id:'market', label:'🏪 Market' }, { id:'engage', label:'💜 Engagement' }]"
);

// 5. Overtime card — insert sebelum training card
const overtimeCard = `
            {(!subTab || subTab === 'overtime') && (
              <div style={S.card}>
                <div style={S.cardTitle}>⏰ Lembur</div>
                {overtime.length === 0 ? <div style={S.empty}>Belum ada lembur</div> : (
                  <ul style={S.list}>{overtime.map((o,i) => (
                    <li key={i} style={S.listItem}>
                      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                        <div>
                          <div style={{fontWeight:'600'}}>{o.date}</div>
                          <div style={{fontSize:'12px',color:'#94a3b8'}}>{o.reason || '-'}</div>
                        </div>
                        <div style={{textAlign:'right'}}>
                          <div style={{fontWeight:'700',color:'#38bdf8'}}>{o.hours}j</div>
                          <span style={S.badge(o.status)}>{o.status}</span>
                        </div>
                      </div>
                    </li>
                  ))}</ul>
                )}
              </div>
            )}

`;
w = w.replace(
  "{(!subTab || subTab === 'training') && (",
  overtimeCard + "{(!subTab || subTab === 'training') && ("
);

// 6. Talent marketplace + ideas — insert sebelum engage
const marketCard = `
            {(!subTab || subTab === 'market') && (
              <>
                <div style={S.card}>
                  <div style={S.cardTitle}>🏪 Talent Marketplace</div>
                  {talentMarket.length === 0 ? <div style={S.empty}>Tidak ada lowongan</div> : (
                    <ul style={S.list}>{talentMarket.map((t,i) => (
                      <li key={i} style={S.listItem}>
                        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                          <div>
                            <div style={{fontWeight:'600'}}>{t.judul}</div>
                            <div style={{fontSize:'12px',color:'#94a3b8'}}>{t.type}</div>
                          </div>
                          <span style={S.badge(t.status)}>{t.status}</span>
                        </div>
                      </li>
                    ))}</ul>
                  )}
                </div>
                <div style={S.card}>
                  <div style={S.cardTitle}>💡 Ide & Suara Karyawan</div>
                  {ideas.length === 0 ? <div style={S.empty}>Belum ada ide</div> : (
                    <ul style={S.list}>{ideas.map((id,i) => (
                      <li key={i} style={S.listItem}>
                        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                          <div>
                            <div style={{fontWeight:'600'}}>{id.title}</div>
                            <div style={{fontSize:'12px',color:'#94a3b8'}}>{id.type} • {(id.description||'').substring(0,50)}</div>
                          </div>
                          <div style={{textAlign:'right'}}>
                            <div style={{color:'#38bdf8',fontSize:'12px'}}>👍 {id.votes||0}</div>
                          </div>
                        </div>
                      </li>
                    ))}</ul>
                  )}
                </div>
              </>
            )}

`;
w = w.replace(
  "{(!subTab || subTab === 'engage') && (\n                <>",
  marketCard + "{(!subTab || subTab === 'engage') && (\n                <>"
);

// 7. Capability card — insert after skills card
const capCard = `
              {capability.length > 0 && (
                <div style={S.card}>
                  <div style={S.cardTitle}>📋 Kompetensi</div>
                  <ul style={S.list}>{capability.map((c,i) => (
                    <li key={i} style={S.listItem}>
                      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                        <span style={{fontWeight:'600'}}>{c.kompetensi}</span>
                        <span style={{fontSize:'12px',color:c.gap>0?'#f87171':'#34d399'}}>
                          Level {c.level_sekarang} → {c.level_target} {c.is_mandatory ? '🔒' : ''}
                        </span>
                      </div>
                    </li>
                  ))}</ul>
                </div>
              )}`;

w = w.replace(
  "skills.length === 0 ? <div style={S.empty}>Belum ada data skills</div>",
  "skills.length === 0 && capability.length === 0 ? <div style={S.empty}>Belum ada data skills</div>"
);

// 8. Medical + exit di profile tab
const medicalCard = `
              {medical.length > 0 && (
                <div style={S.card}>
                  <div style={S.cardTitle}>🏥 Medical Checkup</div>
                  <ul style={S.list}>{medical.map((m,i) => (
                    <li key={i} style={S.listItem}>
                      <div style={{display:'flex',justifyContent:'space-between'}}>
                        <span>{m.checkup_date}</span>
                        <span style={{color:m.result==='Normal'?'#34d399':'#fbbf24'}}>{m.result}</span>
                      </div>
                 
