import { createClient } from '@supabase/supabase-js';
const sb = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const { data } = await sb.from('module_definitions').select('module_group').eq('route_group', 'admin').limit(10);
console.log(JSON.stringify(data));
