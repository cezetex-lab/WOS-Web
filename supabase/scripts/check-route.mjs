import { createClient } from '@supabase/supabase-js';
const sb = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const { data, error } = await sb.from('module_definitions').select('route_path,route_component').eq('route_path', '/admin/career-path');
console.log('data:', JSON.stringify(data), 'error:', error?.message);
