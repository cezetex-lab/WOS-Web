-- ============================================================
-- 050_wave_final_missing_features.sql
-- FIX: candidate_pipeline & vacancies already exist from 018
-- Only add NEW tables + fix RPC functions + seed data
-- ============================================================

-- ── 1. NEW TABLES (only create if not exists) ──

CREATE TABLE IF NOT EXISTS onboarding_tasks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nrp text,
  task_name text NOT NULL,
  category text DEFAULT 'General',
  status text DEFAULT 'Pending',
  due_date date,
  completed_at timestamptz,
  assigned_to text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reviews_360 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reviewee_nrp text NOT NULL,
  reviewer_nrp text NOT NULL,
  relationship text DEFAULT 'Peer',
  leadership_score int DEFAULT 0,
  communication_score int DEFAULT 0,
  teamwork_score int DEFAULT 0,
  innovation_score int DEFAULT 0,
  overall_score int DEFAULT 0,
  comments text,
  period text,
  status text DEFAULT 'Pending',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS forum_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nrp text NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  category text DEFAULT 'Umum',
  replies_count int DEFAULT 0,
  likes_count int DEFAULT 0,
  pinned boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS forum_replies (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  nrp text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS screening_results (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  candidate_name text NOT NULL,
  check_type text NOT NULL,
  status text DEFAULT 'Pending',
  result jsonb,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ══════════════════════════════════════════════════════════════
-- RPC FUNCTIONS (FIX: use existing table columns)
-- ══════════════════════════════════════════════════════════════

-- ── RECRUITMENT: Vacancies (use existing table: id TEXT, position, department, quota) ──
CREATE OR REPLACE FUNCTION get_vacancy_list()
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', v.id, 'title', v.position, 'department', v.department,
      'quota', v.quota, 'status', v.status,
      'applicants', v.app_count,
      'created_at', v.created_at
    )
  ), '[]'::jsonb)
  FROM (
    SELECT v2.id, v2.position, v2.department, v2.quota, v2.status, v2.created_at,
           (SELECT count(*)::int FROM candidate_pipeline cp WHERE cp.vacancy_id = v2.id) AS app_count
    FROM vacancies v2
    ORDER BY v2.created_at DESC
  ) v;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── RECRUITMENT: Pipeline (use existing table: id TEXT, vacancy_id TEXT, nrp, nama, email, stage) ──
CREATE OR REPLACE FUNCTION get_candidate_pipeline(p_vacancy_id text DEFAULT NULL)
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', cp.id, 'candidate_name', cp.nama, 'candidate_email', cp.email,
      'stage', cp.stage, 'notes', cp.notes, 'nrp', cp.nrp,
      'vacancy_id', cp.vacancy_id, 'created_at', cp.created_at
    )
  ), '[]'::jsonb)
  FROM candidate_pipeline cp
  WHERE (p_vacancy_id IS NULL OR cp.vacancy_id = p_vacancy_id)
  ORDER BY cp.created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION move_candidate(p_id text, p_stage text)
RETURNS jsonb AS $$
BEGIN
  UPDATE candidate_pipeline SET stage = p_stage WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'message', 'Moved to ' || p_stage);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── ONBOARDING ──
CREATE OR REPLACE FUNCTION get_onboarding_tasks(p_nrp text DEFAULT NULL)
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', t.id, 'nrp', t.nrp, 'task_name', t.task_name,
      'category', t.category, 'status', t.status,
      'due_date', t.due_date, 'assigned_to', t.assigned_to
    )
  ), '[]'::jsonb)
  FROM onboarding_tasks t
  WHERE (p_nrp IS NULL OR t.nrp = p_nrp)
  ORDER BY t.due_date;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── 360° REVIEW ──
CREATE OR REPLACE FUNCTION get_reviews_360(p_nrp text DEFAULT NULL)
RETURNS jsonb AS $$
  SELECT jsonb_build_object(
    'reviews', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', r.id, 'reviewer_nrp', r.reviewer_nrp,
        'relationship', r.relationship, 'overall_score', r.overall_score,
        'leadership_score', r.leadership_score, 'communication_score', r.communication_score,
        'teamwork_score', r.teamwork_score, 'innovation_score', r.innovation_score,
        'comments', r.comments, 'status', r.status
      )
    ), '[]'::jsonb),
    'summary', jsonb_build_object(
      'avg_leadership', (SELECT COALESCE(AVG(leadership_score), 0)::int FROM reviews_360 WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp)),
      'avg_communication', (SELECT COALESCE(AVG(communication_score), 0)::int FROM reviews_360 WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp)),
      'avg_teamwork', (SELECT COALESCE(AVG(teamwork_score), 0)::int FROM reviews_360 WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp)),
      'avg_innovation', (SELECT COALESCE(AVG(innovation_score), 0)::int FROM reviews_360 WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp)),
      'total_reviews', (SELECT count(*)::int FROM reviews_360 WHERE (p_nrp IS NULL OR reviewee_nrp = p_nrp))
    )
  )
  FROM reviews_360 r
  WHERE (p_nrp IS NULL OR r.reviewee_nrp = p_nrp)
  ORDER BY r.created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── FORUM ──
CREATE OR REPLACE FUNCTION get_forum_posts()
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', fp.id, 'nrp', fp.nrp, 'title', fp.title,
      'content', fp.content, 'category', fp.category,
      'replies_count', fp.replies_count, 'likes_count', fp.likes_count,
      'pinned', fp.pinned, 'created_at', fp.created_at
    )
  ), '[]'::jsonb)
  FROM forum_posts fp
  ORDER BY fp.pinned DESC, fp.created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_forum_post(p_nrp text, p_title text, p_content text, p_category text DEFAULT 'Umum')
RETURNS jsonb AS $$
DECLARE new_id uuid;
BEGIN
  INSERT INTO forum_posts (nrp, title, content, category) VALUES (p_nrp, p_title, p_content, p_category) RETURNING id INTO new_id;
  RETURN jsonb_build_object('ok', true, 'id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reply_forum_post(p_post_id uuid, p_nrp text, p_content text)
RETURNS jsonb AS $$
BEGIN
  INSERT INTO forum_replies (post_id, nrp, content) VALUES (p_post_id, p_nrp, p_content);
  UPDATE forum_posts SET replies_count = replies_count + 1 WHERE id = p_post_id;
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── SCREENING ──
CREATE OR REPLACE FUNCTION get_screening_results()
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', s.id, 'candidate_name', s.candidate_name,
      'check_type', s.check_type, 'status', s.status,
      'notes', s.notes, 'created_at', s.created_at
    )
  ), '[]'::jsonb)
  FROM screening_results s
  ORDER BY s.created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════
-- SEED DATA — Forum Posts (10)
-- ══════════════════════════════════════════════════════════════
INSERT INTO forum_posts (nrp, title, content, category, replies_count, likes_count, pinned) VALUES
('NRP001', 'Selamat Datang di Forum Diskusi!', 'Forum ini untuk diskusi internal karyawan. Silakan berbagi ide, saran, dan pertanyaan.', 'Umum', 5, 12, true),
('NRP010', 'Tips Produktivitas Kerja dari Tim Mining', 'Berikut 5 tips yang kami terapkan di site Mining untuk meningkatkan produktivitas harian...', 'Saran', 3, 8, false),
('NRP025', 'Jadwal Training Q3 2026', 'Berikut jadwal training untuk Q3. Mohon daftar jika berminat.', 'Umum', 2, 15, false),
('NRP042', 'Kebijakan Baru WFH 2 Hari/Minggu', 'Mulai Agustus, karyawan boleh WFH 2 hari per minggu. Syarat: penyelesaian target.', 'Kebijakan', 7, 20, false),
('NRP068', 'Pelaporan Insiden K3 — Form Baru', 'Gunakan form baru untuk melaporkan insiden K3. Lebih cepat dan langsung ke tim HSE.', 'K3', 1, 6, false),
('NRP015', 'Ide: Sistem Rekan Sebaya untuk New Hire', 'Agar onboarding lebih smooth, saya usulkan buddy system untuk karyawan baru.', 'Saran', 4, 11, false),
('NRP033', 'Hasil Survei eNPS Q2 — Skor Naik!', 'Skor eNPS naik dari 32 ke 41. Terima kasih atas feedback semua!', 'Umum', 6, 18, false),
('NRP057', 'Workshop K3 untuk Tim Estate', 'Workshop K3 dijadwalkan 15 Sept. Attendance wajib untuk semua mandor.', 'K3', 2, 9, false),
('NRP088', 'Forum: Bagaimana Cara Meningkatkan KPI?', 'Yuk diskusi strategi untuk meningkatkan KPI divisi masing-masing.', 'KPI', 8, 14, false),
('NRP002', 'Pengumuman: Libur Nasional 17 Agustus', 'Seluruh karyawan libur 17 Agustus. Cuti bersama tidak perlu approval.', 'Kebijakan', 1, 25, false)
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- SEED DATA — Forum Replies (15)
-- ══════════════════════════════════════════════════════════════
INSERT INTO forum_replies (post_id, nrp, content) VALUES
((SELECT id FROM forum_posts WHERE title LIKE 'Selamat Datang%' LIMIT 1), 'NRP010', 'Terima kasih! Senang bisa diskusi di sini.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Selamat Datang%' LIMIT 1), 'NRP025', 'Semoga forum ini bermanfaat untuk semua.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Selamat Datang%' LIMIT 1), 'NRP042', 'Setuju! Mari manfaatkan dengan baik.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Tips Produktivitas%' LIMIT 1), 'NRP033', 'Tips yang bagus, sudah kami coba di divisi Estate.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Tips Produktivitas%' LIMIT 1), 'NRP057', 'Bisa sharing lebih detail soal morning briefing?'),
((SELECT id FROM forum_posts WHERE title LIKE 'Kebijakan Baru WFH%' LIMIT 1), 'NRP015', 'Apakah WFH berlaku untuk semua level?'),
((SELECT id FROM forum_posts WHERE title LIKE 'Kebijakan Baru WFH%' LIMIT 1), 'NRP068', 'Bagus! Tapi bagaimana dengan tim lapangan?'),
((SELECT id FROM forum_posts WHERE title LIKE 'Ide: Sistem Rekan%' LIMIT 1), 'NRP042', 'Ide bagus! Kami sudah coba di divisi Mill.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Hasil Survei%' LIMIT 1), 'NRP001', 'Skor naik! Terima kasih atas feedback-nya.'),
((SELECT id FROM forum_posts WHERE title LIKE 'Hasil Survei%' LIMIT 1), 'NRP088', 'Semoga terus naik di Q3.')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- SEED DATA — 360° Review (20)
-- ══════════════════════════════════════════════════════════════
INSERT INTO reviews_360 (reviewee_nrp, reviewer_nrp, relationship, leadership_score, communication_score, teamwork_score, innovation_score, overall_score, comments, period) VALUES
('NRP010', 'NRP001', 'Manager', 85, 80, 90, 75, 83, 'Pemimpin tim yang baik, komunikatif.', 'Q2-2026'),
('NRP010', 'NRP015', 'Peer', 78, 82, 88, 70, 80, 'Kolaboratif dan supportive.', 'Q2-2026'),
('NRP010', 'NRP020', 'Subordinate', 80, 75, 85, 72, 78, 'Bisa lebih delegate tugas.', 'Q2-2026'),
('NRP025', 'NRP001', 'Manager', 70, 85, 80, 82, 79, 'Komunikasi Excellent, inovatif.', 'Q2-2026'),
('NRP025', 'NRP030', 'Peer', 72, 80, 78, 85, 79, 'Ide-ide segar, perlu lebih fokus.', 'Q2-2026'),
('NRP033', 'NRP002', 'Manager', 88, 82, 85, 80, 84, 'Konsisten dalam pencapaian target.', 'Q2-2026'),
('NRP033', 'NRP035', 'Peer', 82, 78, 82, 78, 80, 'Tim player yang solid.', 'Q2-2026'),
('NRP042', 'NRP001', 'Manager', 75, 70, 80, 85, 78, 'Inovatif tapi perlu improve komunikasi.', 'Q2-2026'),
('NRP042', 'NRP045', 'Peer', 78, 72, 82, 88, 80, 'Selalu punya ide baru yang menarik.', 'Q2-2026'),
('NRP057', 'NRP002', 'Manager', 90, 88, 92, 85, 89, 'Excellent leadership, sangat dihormati tim.', 'Q2-2026'),
('NRP057', 'NRP060', 'Peer', 85, 90, 88, 80, 86, 'Mentor yang baik untuk junior.', 'Q2-2026'),
('NRP068', 'NRP001', 'Manager', 82, 78, 85, 80, 81, 'Reliable, tugas selesai tepat waktu.', 'Q2-2026'),
('NRP068', 'NRP070', 'Peer', 80, 82, 80, 78, 80, 'Konsisten dan disiplin.', 'Q2-2026'),
('NRP075', 'NRP002', 'Manager', 76, 80, 78, 82, 79, 'Perlu lebih confident dalam presentasi.', 'Q2-2026'),
('NRP075', 'NRP078', 'Peer', 74, 78, 80, 80, 78, 'Kerja keras, tapi perlu networking lebih.', 'Q2-2026'),
('NRP088', 'NRP001', 'Manager', 92, 90, 88, 88, 90, 'Top performer, role model untuk tim.', 'Q2-2026'),
('NRP088', 'NRP090', 'Peer', 88, 92, 90, 85, 89, 'Inspirasi untuk semua rekan kerja.', 'Q2-2026'),
('NRP095', 'NRP002', 'Manager', 68, 72, 75, 70, 71, 'Perlu coaching untuk improve performance.', 'Q2-2026'),
('NRP095', 'NRP098', 'Peer', 65, 70, 72, 68, 69, 'Masih perlu guidance lebih banyak.', 'Q2-2026'),
('NRP100', 'NRP001', 'Manager', 86, 84, 88, 82, 85, 'Sangat appreciate kerja kerasnya.', 'Q2-2026')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- SEED DATA — Screening Results (10)
-- ══════════════════════════════════════════════════════════════
INSERT INTO screening_results (candidate_name, check_type, status, notes) VALUES
('Ahmad Rizki', 'Background', 'Passed', 'Clean record, referensi positif dari universitas.'),
('Siti Nurhaliza', 'Background', 'Passed', 'Tidak ada catatan kriminal.'),
('Budi Santoso', 'Background', 'Failed', 'Ada catatan PHK sebelumnya.'),
('Dewi Lestari', 'Medical', 'Passed', 'Sehat jasmani, tidak ada riwayat penyakit kronis.'),
('Eko Prasetyo', 'Medical', 'Passed', 'Vision test passed, tinggi 170cm.'),
('Fina Amelia', 'Medical', 'Pending', 'Menunggu hasil laboratorium.'),
('Gunawan Wibowo', 'Reference', 'Passed', 'Referensi dari mantan atasan: Excellent.'),
('Hana Permata', 'Reference', 'Passed', 'Referensi dari kampus: Cum Laude.'),
('Indra Kusuma', 'Education', 'Passed', 'S1 Teknik Informatika, IPK 3.8.'),
('Julia Rahmawati', 'Education', 'Failed', 'Ijazah tidak terverifikasi.')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- SEED DATA — Onboarding Tasks (15)
-- ══════════════════════════════════════════════════════════════
INSERT INTO onboarding_tasks (nrp, task_name, category, status, due_date, assigned_to) VALUES
('NRP001', 'Setup email & akun sistem', 'IT', 'Completed', '2026-08-01', 'IT Helpdesk'),
('NRP001', 'Orientation kantor pusat', 'HR', 'Completed', '2026-08-02', 'HRD'),
('NRP001', 'Seragam kerja & ID card', 'Facility', 'Completed', '2026-08-03', 'GA'),
('NRP001', 'Training safety induction', 'Training', 'Completed', '2026-08-05', 'HSE'),
('NRP010', 'Setup email & akun sistem', 'IT', 'Completed', '2026-07-15', 'IT Helpdesk'),
('NRP010', 'Buddy pairing dengan senior', 'HR', 'Completed', '2026-07-16', 'HRD'),
('NRP010', 'Tour fasilitas kantor & site', 'Facility', 'Completed', '2026-07-17', 'GA'),
('NRP025', 'Setup email & akun sistem', 'IT', 'InProgress', '2026-09-01', 'IT Helpdesk'),
('NRP025', 'Orientation divisi', 'HR', 'Pending', '2026-09-02', 'HRD'),
('NRP025', 'Training K3 wajib', 'Training', 'Pending', '2026-09-05', 'HSE'),
('NRP033', 'Setup workstation', 'IT', 'Completed', '2026-06-01', 'IT Helpdesk'),
('NRP033', 'Onboarding meeting dengan manager', 'HR', 'Completed', '2026-06-02', 'Manager'),
('NRP042', 'Setup email & akun sistem', 'IT', 'InProgress', '2026-09-10', 'IT Helpdesk'),
('NRP042', 'Jadwal training produk', 'Training', 'Pending', '2026-09-15', 'Product Team'),
('NRP057', 'Semua onboarding selesai', 'General', 'Completed', '2026-05-01', 'HRD')
ON CONFLICT DO NOTHING;
