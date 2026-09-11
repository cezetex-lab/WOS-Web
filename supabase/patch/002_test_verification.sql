begin;
select set_config('request.jwt.claim.sub', '97a59592-5578-4ae3-a811-1771300835d5', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"97a59592-5578-4ae3-a811-1771300835d5","role":"authenticated"}', true);
set local role authenticated;
select authz_current_nrp() as current_nrp;
rollback;


begin;
select set_config('request.jwt.claim.sub', '97a59592-5578-4ae3-a811-1771300835d5', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"97a59592-5578-4ae3-a811-1771300835d5","role":"authenticated"}', true);
set local role authenticated;
select get_reviews_360(null) as hasil;
rollback;


select count(*) as jumlah_data_medis from hr_medical_checkup where nrp = 'NRP005';
