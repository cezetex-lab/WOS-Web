-- ============================================================
-- 033: Seed Knowledge Base untuk AI Copilot
-- 10 dokumen kebijakan perusahaan untuk RAG
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- Pastikan tabel ai_documents sudah ada dari migration 007
-- Kalau belum, jalankan 007_pgvector_ai_copilot.sql dulu

-- ── 1. Kebijakan Cuti Tahunan ──
INSERT INTO ai_documents (title, content, context) VALUES
('Kebijakan Cuti Tahunan 2026', 
'Kebijakan Cuti Tahunan insightWOS:
1. PKWTT: 12 hari cuti per tahun
2. PKWT: Cuti proportional berdasarkan masa kerja (1 hari per bulan kerja, maks 12 hari)
3. Pengajuan: Minimal 3 hari sebelumnya melalui sistem
4. Approval: Atasan langsung → HR
5. Sisa cuti hangus di akhir tahun kecuali ada persetujuan carry-over dari HR
6. Cuti darurat: Bisa diajukan H-1 dengan approval manager
7. Blackout period: Tidak ada cuti di akhir bulan kecuali mendesak',
'policy'),

-- ── 2. Kebijakan Lembur ──
('Kebijakan Lembur & Overtime', 
'Kebijakan Lembur insightWOS:
1. Rate lembur: Hari kerja 1.5x, Sabtu 2x, Hari libur nasional 3x, Malam (22:00-07:00) 2x
2. Maksimal lembur: 3 jam per hari, 12 jam per minggu
3. Approval: Atasan langsung harus approve SEBELUM lembur dilakukan
4. Klaim: Harus diajukan dalam 7 hari setelah lembur
5. Bukti: Lampirkan foto/记录 aktivitas lembur
6. Rejection: Jika ditolak, karyawan bisa appeal ke HR dalam 3 hari
7. Holiday lembur: Harus ada approval HR + manajemen',
'policy'),

-- ── 3. Kebijakan KPI & Performa ──
('Sistem KPI & Penilaian Kinerja', 
'Sistem KPI insightWOS:
1. Komponen KPI: Kehadiran (30%), Produktivitas (40%), Sikap Kerja (20%), Inisiatif (10%)
2. Skor KPI: 0-100, target minimum 70
3. Perhitungan: Otomatis setiap akhir bulan oleh sistem
4. Evaluasi: Bulanan (manager review), Kuartal内 (HR review), Tahunan (board review)
5. Bonus: KPI ≥ 90 = bonus 100%, 80-89 = 75%, 70-79 = 50%, < 70 = 0%
6. Peningkatan: Jika KPI naik ≥ 20 poin dalam 3 bulan, dapat recognition
7. Peringatan: KPI < 50 selama 2 bulan berturut-turut = warning letter
8. Target: Ditentukan oleh atasan langsung, disetujui HR',
'kpi'),

-- ── 4. Kebijakan Gaji & Tunjangan ──
('Struktur Gaji dan Tunjangan', 
'Struktur Kompensasi insightWOS:
1. Komponen gaji: Gaji Pokok + Tunjangan Tetap (transport, makan, komunikasi) + Tunjangan Tidak Tetap (lembur, shift)
2. Potongan: BPJS Kesehatan 4%, BPJS Ketenagakerjaan (JHT 3.7%, JP 2%), PPh21 (progressive)
3. Slip gaji: Tersedia setiap tanggal 25 melalui sistem
4. Kenaikan gaji: Review tahunan, biasanya 5-15% tergantung KPI
5. Bonus: Tahunan (1 bulan gaji untuk KPI ≥ 80), Performance bonus (kuartal)
6. THR: 1 bulan gaji, dibayar H-7 Lebaran
7. Benefit: BPJS Kesehatan, BPJS Ketenagakerjaan, Asuransi Tambahan, Cuti Tambahan
8. Payroll cycle: 25 hari per bulan, transfer tanggal 27',
'payroll'),

-- ── 5. Kebijakan Kehadiran ──
('Sistem Kehadiran & Absensi', 
'Sistem Kehadiran insightWOS:
1. Jam kerja: 08:00 - 17:00 WIB (1 jam istirahat 12:00-13:00)
2. Absensi: Fingerprint/Face recognition di entrance
3. toleransi keterlambatan: 15 menit ( maksimal 3x per bulan)
4. WFH: Maksimal 2 hari per minggu dengan approval atasan
5. Izin: Harus disetujui atasan, max 3 hari per bulan
6. Sakit: Surat dokumen wajib jika ≥ 2 hari
7. Remote: Diizinkan untuk posisi tertentu, jam kerja tetap 08:00-17:00
8. Tracking: Real-time monitoring via dashboard manager',
'attendance'),

-- ── 6. Kebijakan Remote Work ──
('Kebijakan Remote & Work From Home', 
'Kebijakan Remote Work insightWOS:
1. WFH: Maksimal 2 hari per minggu
2. Remote: Untuk posisi tertentu (marketing, design, dev) bisa full remote
3. Jam tetap: Harus online 08:00-17:00 WIB
4. Approval: Atasan langsung + HR untuk permanent remote
5. Pengajuan: Minimal 1 hari sebelumnya melalui sistem
6. Larangan: Tidak boleh remote saat ada meeting penting atau audit
7. Monitoring: Check-in via Slack/Teams jam 09:00 dan 15:00
8. Evaluasi: 3 bulan sekali, jika performa turun → wajib WFO',
'policy'),

-- ── 7. Onboarding Karyawan Baru ──
('Proses Onboarding Karyawan Baru', 
'Proses Onboarding insightWOS:
Hari 1: Orientasi
- Presentasi perusahaan, visi-misi, budaya
- Tour facility
- Daftar sistem (email, Absen, tools)
- Meet HR team

Hari 2: Training
- Training sistem HR (insightWOS)
- Training tools kerja (sesuai divisi)
- Safety briefing

Hari 3: Integration
- Meet the team
- Assigned buddy (senior 1 divisi)
- First task assignment

Milestone 30 hari:
- Week 1: Adaptasi lingkungan
- Week 2: Mulai pekerjaan ringan
- Week 3: Review pertama dengan atasan
- Week 4: Evaluasi onboarding dengan HR',
'general'),

-- ── 8. Career Path & Promosi ──
('Jalur Karir dan Kebijakan Promosi', 
'Jalur Karir insightWOS:
Level: Staff → Senior Staff → Supervisor → Manager → Senior Manager → Director

Kriteria Promosi:
1. Masa kerja minimal 1 tahun di level saat ini
2. KPI konsisten ≥ 80 selama 4 kuartal terakhir
3. Rekomendasi atasan langsung
4. Assessment center (untuk level Manager ke atas)
5. Tidak ada warning letter aktif

Proses:
1. Nominasi oleh atasan langsung
2. Review oleh HR
3. Assessment (skill test + interview)
4. Decision oleh board (untuk Director)
5. Effective date: Awal kuartal berikutnya

Salary Range per Level:
- Staff: 4-6 juta
- Senior Staff: 6-9 juta
- Supervisor: 9-13 juta
- Manager: 13-20 juta
- Senior Manager: 20-30 juta
- Director: 30-50 juta',
'general'),

-- ── 9. Kebijakan disciplinary ──
('Kebijakan Disiplin & Sanksi', 
'Kebijakan Disiplin insightWOS:
Level 1 - Verbal Warning:
- Keterlambatan 3x dalam sebulan
- Lupa absensi 1x
- Tidak pakai seragam

Level 2 - Written Warning:
- Keterlambatan 5x dalam sebulan
- WFH tanpa approval
- Tidak menyelesaikan task deadline

Level 3 - Final Warning:
- Keterlambatan 10x dalam sebulan
- Menolak pejabat wajar
- Kesalahan berulang level 2

Level 4 - Pemutusan Hubungan:
- Fraud / pencurian
- Kekerasan di tempat kerja
- Pelanggaran berat lainnya

Proses:
1. Investigasi oleh HR
2. Hearing dengan karyawan
3. Keputusan oleh komite disiplin
4. Surat peringatan resmi
5. Appeal dalam 7 hari ke Direksi',
'policy'),

-- ── 10. Kebijakan Pengembangan Diri ──
('Kebijakan Training & Pengembangan Diri', 
'Kebijakan Pengembangan Diri insightWOS:
1. Training Budget: Rp 5 juta/karyawan/tahun untuk PKWTT
2. Jenis: Technical training, Soft skills, Leadership, Certification
3. Pengajuan: Melalui sistem, approval atasan → HR → Finance
4. Bonding period: Training > Rp 10 juta = bond 1 tahun
5. Sertifikasi: Didukung penuh (biaya + waktu belajar)
6. Internal training: Gratis, setiap bulan ada sesi
7. E-learning: Akses ke platform learning (Rp 500rb/karyawan/tahun)
8. Conference: Maksimal 1x per tahun, budget max Rp 15 juta
9. Tujuan: Meningkatkan skill, retensi karyawan, competitive advantage
10. Evaluasi: Post-training assessment wajib',
'policy');

-- ── Verify ──
SELECT count(*) as total_documents FROM ai_documents;
