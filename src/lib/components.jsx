'use client';

import { useState } from 'react';

// ============================================================
// MULTI-STEP FORM Ã¢â‚¬â€ Cuti / Lembur / Training
// ============================================================
export function MultiStepForm({ type, onSubmit, onCancel }) {
  const [step, setStep] = useState(1);
  const [data, setData] = useState({ type, reason: '', date_from: '', date_to: '', notes: '' });

  const steps = {
    cuti: [
      { label: 'Jenis Cuti', fields: ['jenis_cuti'] },
      { label: 'Detail', fields: ['date_from', 'date_to', 'reason'] },
      { label: 'Konfirmasi', fields: ['notes'] }
    ],
    lembur: [
      { label: 'Detail Lembur', fields: ['date_from', 'date_from_time', 'date_to_time', 'reason'] },
      { label: 'Deskripsi', fields: ['notes'] },
      { label: 'Konfirmasi', fields: [] }
    ],
    training: [
      { label: 'Pilih Training', fields: ['training_code'] },
      { label: 'Alasan', fields: ['reason', 'notes'] },
      { label: 'Konfirmasi', fields: [] }
    ]
  };

  const cfg = steps[type] || steps.cuti;
  const totalSteps = cfg.length;
  const icons = { cuti: 'Ã°Å¸Ââ€“Ã¯Â¸Â', lembur: 'Ã¢ÂÂ°', training: 'Ã°Å¸â€œÅ¡' };

  function update(field, val) {
    setData(prev => ({ ...prev, [field]: val }));
  }

  function canNext() {
    const f = cfg[step - 1].fields;
    if (f.length === 0) return true;
    return f.every(field => data[field] && data[field].toString().trim() !== '');
  }

  return (
    <div style={S.formWrap}>
      <div style={S.formHeader}>
        <span style={{fontSize:'20px'}}>{icons[type]}</span>
        <span style={{fontSize:'16px',fontWeight:'700'}}>
          {type === 'cuti' ? 'Pengajuan Cuti' : type === 'lembur' ? 'Pengajuan Lembur' : 'Pengajuan Training'}
        </span>
      </div>

      {/* Progress bar */}
      <div style={{display:'flex',gap:'4px',marginBottom:'16px'}}>
        {cfg.map((s,i) => (
          <div key={i} style={{flex:1,height:'4px',borderRadius:'2px',background:i < step ? '#38bdf8' : '#334155'}} />
        ))}
      </div>
      <div style={{fontSize:'12px',color:'#94a3b8',marginBottom:'12px'}}>
        Langkah {step} dari {totalSteps}: {cfg[step-1].label}
      </div>

      {/* Step 1 */}
      {step === 1 && type === 'cuti' && (
        <div style={{display:'grid',gap:'8px'}}>
          {['Tahunan','Sakit','Izin Khusus'].map(j => (
            <button key={j} onClick={() => { update('jenis_cuti', j); setStep(2); }}
              style={{...S.btn, background: data.jenis_cuti === j ? '#1e40af' : '#1e293b', border: data.jenis_cuti === j ? '2px solid #38bdf8' : '1px solid #334155', textAlign:'left'}}>
              {j}
            </button>
          ))}
        </div>
      )}

      {step === 1 && type === 'lembur' && (
        <div style={{display:'grid',gap:'8px'}}>
          <label style={S.label}>Tanggal</label>
          <input type="date" value={data.date_from || ''} onChange={e => update('date_from', e.target.value)} style={S.input} />
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:'8px'}}>
            <div><label style={S.label}>Jam Mulai</label><input type="time" value={data.date_from_time || ''} onChange={e => update('date_from_time', e.target.value)} style={S.input} /></div>
            <div><label style={S.label}>Jam Selesai</label><input type="time" value={data.date_to_time || ''} onChange={e => update('date_to_time', e.target.value)} style={S.input} /></div>
          </div>
          <label style={S.label}>Alasan Lembur</label>
          <textarea value={data.reason || ''} onChange={e => update('reason', e.target.value)} style={{...S.input,minHeight:'60px'}} placeholder="Jelaskan alasan lembur..." />
        </div>
      )}

      {step === 1 && type === 'training' && (
        <div style={{display:'grid',gap:'8px'}}>
          <label style={S.label}>Kode Training</label>
          <input value={data.training_code || ''} onChange={e => update('training_code', e.target.value)} style={S.input} placeholder="Contoh: TRN-001" />
        </div>
      )}

      {/* Step 2 */}
      {step === 2 && (
        <div style={{display:'grid',gap:'8px'}}>
          {(type === 'cuti') && (
            <>
              <label style={S.label}>Dari Tanggal</label>
              <input type="date" value={data.date_from || ''} onChange={e => update('date_from', e.target.value)} style={S.input} />
              <label style={S.label}>Sampai Tanggal</label>
              <input type="date" value={data.date_to || ''} onChange={e => update('date_to', e.target.value)} style={S.input} />
              <label style={S.label}>Alasan / Keterangan</label>
              <textarea value={data.reason || ''} onChange={e => update('reason', e.target.value)} style={{...S.input,minHeight:'60px'}} placeholder="Jelaskan alasan cuti..." />
            </>
          )}
          {(type === 'lembur' || type === 'training') && (
            <>
              <label style={S.label}>Catatan Tambahan</label>
              <textarea value={data.notes || ''} onChange={e => update('notes', e.target.value)} style={{...S.input,minHeight:'60px'}} placeholder="Catatan (opsional)..." />
              {type === 'training' && (
                <>
                  <label style={S.label}>Alasan Mengikuti Training</label>
                  <textarea value={data.reason || ''} onChange={e => update('reason', e.target.value)} style={{...S.input,minHeight:'60px'}} placeholder="Jelaskan manfaat training ini..." />
                </>
              )}
            </>
          )}
        </div>
      )}

      {/* Step 3 Ã¢â‚¬â€ Confirmation */}
      {step === 3 && (
        <div>
          <div style={S.card}>
            <div style={{fontSize:'13px',fontWeight:'700',color:'#38bdf8',marginBottom:'8px'}}>Ã°Å¸â€œâ€¹ Ringkasan Pengajuan</div>
            {data.jenis_cuti && <div style={S.row}><span style={{color:'#94a3b8'}}>Jenis</span><span>{data.jenis_cuti}</span></div>}
            {data.training_code && <div style={S.row}><span style={{color:'#94a3b8'}}>Training</span><span>{data.training_code}</span></div>}
            {data.date_from && <div style={S.row}><span style={{color:'#94a3b8'}}>Dari</span><span>{data.date_from}</span></div>}
            {data.date_to && <div style={S.row}><span style={{color:'#94a3b8'}}>Sampai</span><span>{data.date_to}</span></div>}
            {data.date_from_time && <div style={S.row}><span style={{color:'#94a3b8'}}>Jam</span><span>{data.date_from_time} - {data.date_to_time}</span></div>}
            {data.reason && <div style={S.row}><span style={{color:'#94a3b8'}}>Alasan</span><span style={{flex:2,textAlign:'right'}}>{data.reason}</span></div>}
          </div>
        </div>
      )}

      {/* Navigation */}
      <div style={{display:'flex',gap:'8px',marginTop:'16px'}}>
        {step > 1 && <button onClick={() => setStep(step - 1)} style={{...S.btn,flex:1}}>Ã¢â€ Â Kembali</button>}
        {step < totalSteps ? (
          <button onClick={() => setStep(step + 1)} disabled={!canNext()}
            style={{...S.btn,flex:2,background: canNext() ? '#1e40af' : '#334155',opacity: canNext() ? 1 : 0.5}}>
            Lanjut Ã¢â€ â€™
          </button>
        ) : (
          <button onClick={() => onSubmit(data)} style={{...S.btn,flex:2,background:'#16a34a'}}>
            Ã¢Å“â€¦ Kirim Pengajuan
          </button>
        )}
        <button onClick={onCancel} style={{...S.btn,background:'#dc2626',flex:1}}>Batal</button>
      </div>
    </div>
  );
}

// ============================================================
// TASK BOARD Ã¢â‚¬â€ Kanban (To Do / Doing / Done)
// ============================================================
export function TaskBoard({ tasks, onUpdateStatus, onCreateTask }) {
  const [view, setView] = useState('board');
  const [newTitle, setNewTitle] = useState('');
  const [newPriority, setNewPriority] = useState('medium');
  const [newDue, setNewDue] = useState('');
  const cols = [
    { id: 'todo', label: 'Ã°Å¸â€œâ€¹ To Do', color: '#f59e0b' },
    { id: 'doing', label: 'Ã°Å¸â€Â¨ Doing', color: '#38bdf8' },
    { id: 'done', label: 'Ã¢Å“â€¦ Done', color: '#34d399' }
  ];

  const priColors = { high: '#f87171', medium: '#fbbf24', low: '#34d399' };

  function handleCreate() {
    if (!newTitle.trim()) return;
    onCreateTask({ title: newTitle, priority: newPriority, due_date: newDue });
    setNewTitle('');
    setNewPriority('medium');
    setNewDue('');
  }

  return (
    <div>
      <div style={{display:'flex',gap:'8px',marginBottom:'12px'}}>
        <button onClick={() => setView('board')} style={{...S.btn, background: view==='board' ? '#1e40af' : '#1e293b', flex:1}}>Ã°Å¸â€”â€šÃ¯Â¸Â Board</button>
        <button onClick={() => setView('create')} style={{...S.btn, background: view==='create' ? '#1e40af' : '#1e293b', flex:1}}>Ã¢Å¾â€¢ Buat Task</button>
      </div>

      {view === 'board' && (
        <div style={{display:'grid',gap:'12px'}}>
          {cols.map(col => {
            const items = tasks.filter(t => t.status === col.id);
            return (
              <div key={col.id} style={S.card}>
                <div style={{fontSize:'14px',fontWeight:'700',color:col.color,marginBottom:'8px'}}>
                  {col.label} ({items.length})
                </div>
                {items.length === 0 && <div style={{fontSize:'12px',color:'#475569',padding:'8px'}}>Kosong</div>}
                {items.map(t => (
                  <div key={t.id} style={{...S.listItem,borderLeft:`3px solid ${priColors[t.priority] || '#475569'}`}}>
                    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                      <span style={{fontWeight:'600',fontSize:'13px'}}>{t.title}</span>
                      <span style={{fontSize:'10px',color:'#64748b',background:'#0f172a',padding:'2px 6px',borderRadius:'4px'}}>{t.priority}</span>
                    </div>
                    {t.due_date && <div style={{fontSize:'11px',color:'#94a3b8',marginTop:'4px'}}>Ã°Å¸â€œâ€¦ {t.due_date}</div>}
                    <div style={{display:'flex',gap:'4px',marginTop:'6px'}}>
                      {cols.filter(c => c.id !== t.status).map(c => (
                        <button key={c.id} onClick={() => onUpdateStatus(t.id, c.id)}
                          style={{fontSize:'10px',padding:'3px 8px',borderRadius:'4px',border:'1px solid #334155',background:'#0f172a',color:'#e2e8f0',cursor:'pointer'}}>
                          Ã¢â€ â€™ {c.label.split(' ')[1]}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      )}

      {view === 'create' && (
        <div style={S.card}>
          <label style={S.label}>Judul Task</label>
          <input value={newTitle} onChange={e => setNewTitle(e.target.value)} style={S.input} placeholder="Judul task..." />
          <label style={S.label}>Prioritas</label>
          <div style={{display:'flex',gap:'8px'}}>
            {['high','medium','low'].map(p => (
              <button key={p} onClick={() => setNewPriority(p)}
                style={{...S.btn,flex:1, background: newPriority === p ? priColors[p] : '#1e293b', color: newPriority === p ? '#0f172a' : '#e2e8f0', fontWeight:'600'}}>
                {p === 'high' ? 'Ã°Å¸â€Â´ Tinggi' : p === 'medium' ? 'Ã°Å¸Å¸Â¡ Sedang' : 'Ã°Å¸Å¸Â¢ Rendah'}
              </button>
            ))}
          </div>
          <label style={S.label}>Batas Waktu</label>
          <input type="date" value={newDue} onChange={e => setNewDue(e.target.value)} style={S.input} />
          <button onClick={handleCreate} disabled={!newTitle.trim()}
            style={{...S.btn, background:'#16a34a', marginTop:'12px', opacity: newTitle.trim() ? 1 : 0.5}}>
            Ã¢Å“â€¦ Simpan Task
          </button>
        </div>
      )}
    </div>
  );
}

// ============================================================
// OKR CARD
// ============================================================
export function OKRCard({ okrs }) {
  const [expanded, setExpanded] = useState(null);

  if (!okrs || okrs.length === 0) return (
    <div style={{...S.card, textAlign:'center', color:'#64748b'}}>
      <div style={{fontSize:'32px',marginBottom:'8px'}}>Ã°Å¸Å½Â¯</div>
      <div style={{fontSize:'13px'}}>Belum ada OKR. Buat OKR baru untuk mulai tracking.</div>
    </div>
  );

  const statusColors = { on_track: '#34d399', at_risk: '#fbbf24', behind: '#f87171', completed: '#38bdf8' };
  const statusLabel = { on_track: 'Ã°Å¸Å¸Â¢ On Track', at_risk: 'Ã°Å¸Å¸Â¡ At Risk', behind: 'Ã°Å¸â€Â´ Behind', completed: 'Ã¢Å“â€¦ Completed' };

  return (
    <div style={{display:'grid',gap:'8px'}}>
      {okrs.map((o, i) => {
        const avgPct = o.key_results && o.key_results.length > 0
          ? Math.round(o.key_results.reduce((s, kr) => s + (kr.pct || 0), 0) / o.key_results.length)
          : 0;

        return (
          <div key={o.id || i} style={S.card} onClick={() => setExpanded(expanded === i ? null : i)}>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',cursor:'pointer'}}>
              <div>
                <div style={{fontSize:'13px',fontWeight:'700'}}>{o.objective}</div>
                <div style={{fontSize:'11px',color:'#94a3b8',marginTop:'2px'}}>{o.periode}</div>
              </div>
              <div style={{textAlign:'right'}}>
                <div style={{fontSize:'16px',fontWeight:'700',color: statusColors[o.status] || '#e2e8f0'}}>{avgPct}%</div>
                <div style={{fontSize:'10px'}}>{statusLabel[o.status] || o.status}</div>
              </div>
            </div>

            {/* Progress bar */}
            <div style={{height:'4px',background:'#334155',borderRadius:'2px',marginTop:'8px'}}>
              <div style={{height:'100%',width:`${avgPct}%`,background: statusColors[o.status] || '#38bdf8',borderRadius:'2px',transition:'width 0.3s'}} />
            </div>

            {/* Expanded: Key Results */}
            {expanded === i && o.key_results && o.key_results.length > 0 && (
              <div style={{marginTop:'12px',borderTop:'1px solid #334155',paddingTop:'8px'}}>
                <div style={{fontSize:'12px',fontWeight:'600',color:'#38bdf8',marginBottom:'6px'}}>Key Results:</div>
                {o.key_results.map((kr, j) => (
                  <div key={j} style={{padding:'6px 0',borderBottom:'1px solid #1e293b'}}>
                    <div style={{display:'flex',justifyContent:'space-between',fontSize:'12px'}}>
                      <span>{kr.kr}</span>
                      <span style={{color: kr.pct >= 80 ? '#34d399' : kr.pct >= 50 ? '#fbbf24' : '#f87171'}}>{kr.actual}/{kr.target} {kr.unit}</span>
                    </div>
                    <div style={{height:'3px',background:'#334155',borderRadius:'2px',marginTop:'4px'}}>
                      <div style={{height:'100%',width:`${Math.min(kr.pct || 0, 100)}%`,background: kr.pct >= 80 ? '#34d399' : kr.pct >= 50 ? '#fbbf24' : '#f87171',borderRadius:'2px'}} />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ============================================================
// SURVEY CARD (eNPS)
// ============================================================
export function SurveyCard({ survey, onSubmit }) {
  const [answers, setAnswers] = useState({});
  const [submitted, setSubmitted] = useState(false);

  if (!survey) return null;

  function handleSubmit() {
    const score = parseInt(answers.q1 || '5');
    onSubmit({ survey_id: survey.id, answers, score });
    setSubmitted(true);
  }

  if (submitted) return (
    <div style={{...S.card, textAlign:'center'}}>
      <div style={{fontSize:'32px',marginBottom:'8px'}}>Ã°Å¸â„¢Â</div>
      <div style={{fontSize:'14px',fontWeight:'600'}}>Terima kasih sudah mengisi survei!</div>
      <div style={{fontSize:'12px',color:'#94a3b8',marginTop:'4px'}}>Jawaban Anda sangat berharga.</div>
    </div>
  );

  return (
    <div style={S.card}>
      <div style={{fontSize:'14px',fontWeight:'700',color:'#38bdf8',marginBottom:'12px'}}>Ã°Å¸â€œâ€¹ {survey.title}</div>
      {survey.questions && survey.questions.map((q, i) => (
        <div key={i} style={{marginBottom:'12px'}}>
          <label style={{...S.label, display:'block', marginBottom:'4px'}}>{q}</label>
          {i === 0 ? (
            <div style={{display:'flex',gap:'4px',flexWrap:'wrap'}}>
              {[0,1,2,3,4,5,6,7,8,9,10].map(n => (
                <button key={n} onClick={() => setAnswers(prev => ({...prev, q1: n.toString()}))}
                  style={{width:'36px',height:'36px',borderRadius:'8px',border: answers.q1 === n.toString() ? '2px solid #38bdf8' : '1px solid #334155',
                    background: answers.q1 === n.toString() ? '#1e40af' : '#0f172a', color:'#e2e8f0', fontSize:'13px', fontWeight:'600', cursor:'pointer'}}>
                  {n}
                </button>
              ))}
            </div>
          ) : (
            <textarea value={answers[`q${i+1}`] || ''} onChange={e => setAnswers(prev => ({...prev, [`q${i+1}`]: e.target.value }))}
              style={{...S.input,minHeight:'50px'}} placeholder="Jawaban Anda..." />
          )}
        </div>
      ))}
      <button onClick={handleSubmit} disabled={!answers.q1}
        style={{...S.btn,background:'#16a34a',width:'100%',opacity: answers.q1 ? 1 : 0.5,marginTop:'8px'}}>
        Ã¢Å“â€¦ Kirim Jawaban
      </button>
    </div>
  );
}

// Styles
const S = {
  formWrap: { background:'#1e293b', borderRadius:'12px', padding:'16px', border:'1px solid #334155' },
  formHeader: { display:'flex',alignItems:'center',gap:'8px',marginBottom:'12px' },
  card: { background:'#1e293b', borderRadius:'12px', padding:'16px', marginBottom:'12px', border:'1px solid #334155' },
  btn: { padding:'10px 16px', borderRadius:'8px', border:'none', cursor:'pointer', fontSize:'13px', fontWeight:'600', color:'#e2e8f0', background:'#1e293b', transition:'all 0.2s' },
  input: { width:'100%', padding:'10px 12px', borderRadius:'8px', border:'1px solid #334155', background:'#0f172a', color:'#e2e8f0', fontSize:'13px', marginBottom:'8px', boxSizing:'border-box' },
  label: { fontSize:'12px', color:'#94a3b8', fontWeight:'600', marginBottom:'4px', display:'block' },
  listItem: { padding:'12px', borderBottom:'1px solid #1e293b', background:'#0f172a', borderRadius:'8px', marginBottom:'4px' },
  row: { display:'flex', justifyContent:'space-between', padding:'6px 0', borderBottom:'1px solid #1e293b', fontSize:'13px' },
};
