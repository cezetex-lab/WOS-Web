-- ============================================================
-- 048_enable_rls_remaining.sql
-- Enable RLS on 10 tables that are missing it
-- All are catalog/config tables — read for all, write for admin only
-- ============================================================

-- 1. Enable RLS on all 10 tables
ALTER TABLE IF EXISTS hr_benefit_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_coaching_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_competency_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_compliance_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_document_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_penalty_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_position_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_succession_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS hr_training_catalog ENABLE ROW LEVEL SECURITY;

-- 2. Catalog tables: everyone can read, admin can write
-- hr_benefit_catalog
CREATE POLICY "benefit_catalog_read" ON hr_benefit_catalog FOR SELECT USING (true);
CREATE POLICY "benefit_catalog_admin" ON hr_benefit_catalog FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_coaching_catalog
CREATE POLICY "coaching_catalog_read" ON hr_coaching_catalog FOR SELECT USING (true);
CREATE POLICY "coaching_catalog_admin" ON hr_coaching_catalog FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_competency_matrix
CREATE POLICY "competency_matrix_read" ON hr_competency_matrix FOR SELECT USING (true);
CREATE POLICY "competency_matrix_admin" ON hr_competency_matrix FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_compliance_catalog
CREATE POLICY "compliance_catalog_read" ON hr_compliance_catalog FOR SELECT USING (true);
CREATE POLICY "compliance_catalog_admin" ON hr_compliance_catalog FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_document_types
CREATE POLICY "document_types_read" ON hr_document_types FOR SELECT USING (true);
CREATE POLICY "document_types_admin" ON hr_document_types FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_penalty_matrix
CREATE POLICY "penalty_matrix_read" ON hr_penalty_matrix FOR SELECT USING (true);
CREATE POLICY "penalty_matrix_admin" ON hr_penalty_matrix FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_position_skills
CREATE POLICY "position_skills_read" ON hr_position_skills FOR SELECT USING (true);
CREATE POLICY "position_skills_admin" ON hr_position_skills FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_relations
CREATE POLICY "relations_read" ON hr_relations FOR SELECT USING (true);
CREATE POLICY "relations_admin" ON hr_relations FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_succession_matrix
CREATE POLICY "succession_matrix_read" ON hr_succession_matrix FOR SELECT USING (true);
CREATE POLICY "succession_matrix_admin" ON hr_succession_matrix FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- hr_training_catalog
CREATE POLICY "training_catalog_read" ON hr_training_catalog FOR SELECT USING (true);
CREATE POLICY "training_catalog_admin" ON hr_training_catalog FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE nrp = auth.uid()::text AND role_level >= 3));

-- ============================================================
-- RLS COMPLETE — All 57+ tables now have RLS enabled
-- ============================================================
