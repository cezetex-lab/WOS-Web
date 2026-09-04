# HELPER PROMPT: Owner Dashboard Implementation (Email-Only Identity)

## CONTEXT
- Owner = SYSTEM INSTALLER, identified by email only
- Owner email: `owner@insightwos.com` (configurable)
- Owner NOT in employees_master table
- Owner bypasses all role-based access control
- No auth_id binding - email check only for simplicity as installer

## SECURITY MODEL (Email-Only)

### Owner Identity Check
```sql
-- RPC pattern for owner verification
DECLARE v_is_owner BOOLEAN;
SELECT EXISTS (
  SELECT 1 FROM auth.users 
  WHERE email = 'owner@insightwos.com' 
  AND id = auth.uid()
  AND is_active = TRUE
) INTO v_is_owner;

IF NOT v_is_owner THEN
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only');
END IF;
```

### Owner-Only Features (Backend Enforced)
All Owner RPCs MUST include this check at the start:
```sql
DECLARE v_ctx JSONB := get_current_user_context();
IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
  RETURN jsonb_build_object('ok', FALSE, 'msg', 'Owner only');
END IF;
```

## CURRENT STATUS

### ✅ Already Working
- Owner login via Supabase Auth (owner@insightwos.com)
- Module Lock (on/off per BU)
- Tier & Pricing (T0-T4 per BU)
- Role Overview (view/edit roles)
- Company Config (63 items)
- Basic audit logging

### ❌ Missing for Wave 1
- RPC naming mismatch: `get_owner_security_settings` vs `owner_get_security_settings`
- SQL `100_owner_wave1.sql` not deployed
- Wave 1 features: Overview Dashboard, Audit Log Viewer, Security Management, BU Management

## IMPLEMENTATION TASKS

### Task 1: Fix RPC Naming Mismatch (CRITICAL)

**File:** `src/pages/OwnerDashboard.jsx` line 75

**Current:**
```jsx
const [s, ls, ss] = await Promise.all([
  rpc('get_active_sessions'), 
  rpc('get_login_attempt_stats'), 
  rpc('get_owner_security_settings')  // WRONG NAME
]);
```

**Fix to:**
```jsx
const [s, ls, ss] = await Promise.all([
  rpc('get_active_sessions'), 
  rpc('get_login_attempt_stats'), 
  rpc('owner_get_security_settings')  // CORRECT NAME (matches SQL)
]);
```

### Task 2: Deploy Wave 1 SQL (CRITICAL)

**File:** `supabase/migrations/100_owner_wave1.sql`

**Action:** Run this entire file in Supabase SQL Editor

**What it does:**
- Creates 12 new RPCs for Wave 1 features
- Adds indexes for performance
- Fixes existing `get_modules_for_owner` to return ALL modules

**Verification:**
```sql
-- After deployment, verify RPCs exist
SELECT proname FROM pg_proc 
WHERE proname LIKE '%owner%' 
OR proname LIKE 'get_owner_%'
OR proname LIKE 'get_audit_%'
ORDER BY proname;
```

Expected RPCs:
- `get_modules_for_owner` (fixed)
- `get_owner_overview_stats`
- `get_owner_employees_by_bu`
- `get_audit_log_v2`
- `get_audit_log_actions`
- `get_active_sessions`
- `owner_force_logout`
- `get_login_attempt_stats`
- `owner_create_bu`
- `owner_update_bu`
- `owner_delete_bu`
- `owner_get_security_settings`

### Task 3: Create Wave 1 Frontend Components

#### 3.1 Overview Dashboard Tab
**File:** `src/pages/OwnerDashboard.jsx`

Add to existing tabs (after "Config"):
```jsx
{activeTab === 'overview' && (
  <OverviewDashboard 
    stats={overviewStats}
    employeesByBu={employeesByBu}
    recentActivity={recentActivity}
  />
)}
```

**Create component:** `src/components/owner/OverviewDashboard.jsx`
```jsx
import { MetricCard } from '@/lib/design-system';

export default function OverviewDashboard({ stats, employeesByBu, recentActivity }) {
  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <MetricCard 
          title="Total Karyawan" 
          value={stats.total_employees} 
          icon="Users" 
        />
        <MetricCard 
          title="Karyawan Aktif" 
          value={stats.active_employees} 
          icon="UserCheck" 
        />
        <MetricCard 
          title="Module Aktif" 
          value={`${stats.enabled_modules}/${stats.total_modules}`} 
          icon="Layers" 
        />
        <MetricCard 
          title="Request Pending" 
          value={stats.pending_requests} 
          icon="Clock" 
        />
      </div>

      {/* System Health */}
      <div className="bg-slate-800 rounded-lg p-4">
        <h3 className="text-lg font-semibold mb-3">System Health</h3>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-slate-400">Database Size:</span>
            <span className="ml-2">{stats.db_size}</span>
          </div>
          <div>
            <span className="text-slate-400">Login 24h:</span>
            <span className="ml-2">{stats.recent_logins_24h}</span>
          </div>
          <div>
            <span className="text-slate-400">Business Units:</span>
            <span className="ml-2">{stats.total_business_units}</span>
          </div>
          <div>
            <span className="text-slate-400">Departments:</span>
            <span className="ml-2">{stats.total_departments}</span>
          </div>
        </div>
      </div>

      {/* Employees by BU */}
      <div className="bg-slate-800 rounded-lg p-4">
        <h3 className="text-lg font-semibold mb-3">Karyawan per Business Unit</h3>
        <div className="space-y-2">
          {employeesByBu.map(bu => (
            <div key={bu.business_unit_id} className="flex justify-between">
              <span>{bu.unit_name}</span>
              <span>{bu.active_employees}/{bu.total_employees} aktif</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

#### 3.2 Audit Log Tab
**File:** `src/pages/OwnerDashboard.jsx`

Add state and loading:
```jsx
const [auditData, setAuditData] = useState({ data: [], total: 0 });
const [auditActions, setAuditActions] = useState([]);
const [auditFilter, setAuditFilter] = useState({ action: null, page: 0 });

const loadAuditLog = useCallback(async () => {
  try {
    const [data, actions] = await Promise.all([
      rpc('get_audit_log_v2', { 
        p_action_type: auditFilter.action,
        p_limit: 50,
        p_offset: auditFilter.page * 50
      }),
      rpc('get_audit_log_actions')
    ]);
    setAuditData(data || { data: [], total: 0 });
    setAuditActions(actions || []);
  } catch (e) { /* silent */ }
}, [auditFilter.action, auditFilter.page]);
```

**Create component:** `src/components/owner/AuditLogViewer.jsx`
```jsx
export default function AuditLogViewer({ data, total, actions, filter, setFilter }) {
  return (
    <div className="space-y-4">
      {/* Filter */}
      <div className="flex gap-2">
        <select 
          value={filter.action || ''}
          onChange={(e) => setFilter({ ...filter, action: e.target.value || null })}
          className="bg-slate-700 rounded px-3 py-2"
        >
          <option value="">Semua Action</option>
          {actions.map(a => (
            <option key={a.action} value={a.action}>
              {a.action} ({a.count})
            </option>
          ))}
        </select>
      </div>

      {/* Table */}
      <div className="bg-slate-800 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-700">
            <tr>
              <th className="px-4 py-2 text-left">Action</th>
              <th className="px-4 py-2 text-left">Target</th>
              <th className="px-4 py-2 text-left">Details</th>
              <th className="px-4 py-2 text-left">Waktu</th>
            </tr>
          </thead>
          <tbody>
            {data.map(log => (
              <tr key={log.id} className="border-t border-slate-700">
                <td className="px-4 py-2">{log.action}</td>
                <td className="px-4 py-2">{log.target_type}:{log.target_id}</td>
                <td className="px-4 py-2">
                  {log.new_value && JSON.stringify(log.new_value).substring(0, 50)}
                </td>
                <td className="px-4 py-2">{new Date(log.created_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="flex justify-between items-center">
        <span className="text-sm text-slate-400">Total: {total}</span>
        <div className="flex gap-2">
          <button 
            onClick={() => setFilter({ ...filter, page: Math.max(0, filter.page - 1) })}
            disabled={filter.page === 0}
            className="px-3 py-1 bg-slate-700 rounded disabled:opacity-50"
          >
            Previous
          </button>
          <button 
            onClick={() => setFilter({ ...filter, page: filter.page + 1 })}
            disabled={(filter.page + 1) * 50 >= total}
            className="px-3 py-1 bg-slate-700 rounded disabled:opacity-50"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
```

#### 3.3 Security Management Tab
**File:** `src/pages/OwnerDashboard.jsx`

Add state:
```jsx
const [sessions, setSessions] = useState([]);
const [loginStats, setLoginStats] = useState({});
const [securitySettings, setSecuritySettings] = useState([]);

const loadSecurity = useCallback(async () => {
  try {
    const [s, ls, ss] = await Promise.all([
      rpc('get_active_sessions'), 
      rpc('get_login_attempt_stats'),
      rpc('owner_get_security_settings')  // FIXED NAME
    ]);
    setSessions(Array.isArray(s) ? s : []);
    setLoginStats(ls || {});
    setSecuritySettings(Array.isArray(ss) ? ss : []);
  } catch (e) { /* silent */ }
}, []);
```

**Create component:** `src/components/owner/SecurityManagement.jsx`
```jsx
export default function SecurityManagement({ sessions, loginStats, securitySettings, onForceLogout }) {
  return (
    <div className="space-y-6">
      {/* Login Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <MetricCard title="Success 24h" value={loginStats.success_24h} icon="CheckCircle" />
        <MetricCard title="Failed 24h" value={loginStats.failed_24h} icon="XCircle" />
        <MetricCard title="Locked Accounts" value={loginStats.locked_accounts} icon="Lock" />
        <MetricCard title="Unique Users 24h" value={loginStats.unique_users_24h} icon="Users" />
      </div>

      {/* Active Sessions */}
      <div className="bg-slate-800 rounded-lg p-4">
        <h3 className="text-lg font-semibold mb-3">Active Sessions</h3>
        <div className="space-y-2">
          {sessions.map(session => (
            <div key={session.nrp} className="flex justify-between items-center">
              <div>
                <span className="font-medium">{session.nama}</span>
                <span className="text-slate-400 text-sm ml-2">{session.nrp}</span>
                <span className="text-slate-400 text-sm ml-2">{session.divisi}</span>
              </div>
              <button 
                onClick={() => onForceLogout(session.nrp)}
                className="px-3 py-1 bg-red-600 rounded text-sm"
              >
                Force Logout
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Security Settings */}
      <div className="bg-slate-800 rounded-lg p-4">
        <h3 className="text-lg font-semibold mb-3">Security Policy</h3>
        <div className="space-y-2">
          {securitySettings.map(setting => (
            <div key={setting.config_key} className="flex justify-between">
              <span>{setting.label}</span>
              <span>{setting.config_value}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

#### 3.4 BU Management Tab
**File:** `src/pages/OwnerDashboard.jsx`

Add state and functions:
```jsx
const [businessUnits, setBusinessUnits] = useState([]);

const loadBusinessUnits = useCallback(async () => {
  try {
    const result = await rpc('get_business_units_for_owner');
    setBusinessUnits(result || []);
  } catch (e) { /* silent */ }
}, []);

const handleCreateBU = async (data) => {
  const result = await rpc('owner_create_bu', {
    p_unit_code: data.unit_code,
    p_unit_name: data.unit_name,
    p_description: data.description
  });
  if (result?.ok) {
    loadBusinessUnits();
  }
};

const handleUpdateBU = async (buId, data) => {
  const result = await rpc('owner_update_bu', {
    p_bu_id: buId,
    p_unit_name: data.unit_name,
    p_description: data.description,
    p_is_active: data.is_active
  });
  if (result?.ok) {
    loadBusinessUnits();
  }
};

const handleDeleteBU = async (buId) => {
  if (!confirm('Hapus Business Unit?')) return;
  const result = await rpc('owner_delete_bu', { p_bu_id: buId });
  if (result?.ok) {
    loadBusinessUnits();
  }
};
```

**Create component:** `src/components/owner/BusinessUnitManagement.jsx`
```jsx
export default function BusinessUnitManagement({ 
  businessUnits, 
  onCreate, 
  onUpdate, 
  onDelete 
}) {
  const [showCreate, setShowCreate] = useState(false);
  const [editing, setEditing] = useState(null);

  return (
    <div className="space-y-4">
      <button 
        onClick={() => setShowCreate(true)}
        className="px-4 py-2 bg-blue-600 rounded"
      >
        + Add Business Unit
      </button>

      {/* BU List */}
      <div className="space-y-2">
        {businessUnits.map(bu => (
          <div key={bu.id} className="bg-slate-800 rounded p-4 flex justify-between">
            <div>
              <h4 className="font-medium">{bu.unit_name}</h4>
              <p className="text-sm text-slate-400">{bu.unit_code} - Tier {bu.tier}</p>
              <p className="text-sm text-slate-400">{bu.description}</p>
            </div>
            <div className="flex gap-2">
              <button 
                onClick={() => setEditing(bu)}
                className="px-3 py-1 bg-slate-700 rounded"
              >
                Edit
              </button>
              <button 
                onClick={() => onDelete(bu.id)}
                className="px-3 py-1 bg-red-600 rounded"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Create Modal */}
      {showCreate && (
        <CreateBUModal 
          onClose={() => setShowCreate(false)}
          onSubmit={onCreate}
        />
      )}

      {/* Edit Modal */}
      {editing && (
        <EditBUModal 
          bu={editing}
          onClose={() => setEditing(null)}
          onSubmit={(data) => onUpdate(editing.id, data)}
        />
      )}
    </div>
  );
}
```

### Task 4: Update Owner Dashboard Tabs

**File:** `src/pages/OwnerDashboard.jsx`

Update tab list:
```jsx
const tabs = [
  { id: 'overview', label: 'Overview', icon: 'LayoutDashboard' },
  { id: 'modules', label: 'Module Lock', icon: 'Lock' },
  { id: 'tier', label: 'Tier & Pricing', icon: 'DollarSign' },
  { id: 'roles', label: 'Roles', icon: 'Users' },
  { id: 'audit', label: 'Audit Log', icon: 'FileText' },
  { id: 'security', label: 'Security', icon: 'Shield' },
  { id: 'bu', label: 'Business Units', icon: 'Building2' },
  { id: 'config', label: 'Config', icon: 'Settings' },
];
```

### Task 5: Deploy Frontend

**Command:**
```bash
cd D:\0insightWOS\WOS-Web
npx vercel deploy --prod
```

## SECURITY CONSIDERATIONS (Email-Only)

### ✅ Acceptable Risks (Email-Only)
- Email change requires Supabase Auth console access
- Owner is trusted installer (not regular user)
- No social engineering risk (internal system)
- Audit log still tracks all owner actions

### 🔒 Required Mitigations
1. **Strong password policy** for owner account
2. **MFA enabled** for owner email
3. **Email change notification** to backup contact
4. **Regular audit** of owner actions
5. **Backup owner** procedure documented

### 🚫 Still Required (Independent of email binding)
- RLS policy tightening (currently too permissive)
- Per-action permission system
- Admin role implementation
- Route guards

## VERIFICATION CHECKLIST

After implementation:

- [ ] RPC naming mismatch fixed in OwnerDashboard.jsx
- [ ] SQL 100_owner_wave1.sql deployed in Supabase
- [ ] All 12 Wave 1 RPCs verified in pg_proc
- [ ] Overview Dashboard tab loads data
- [ ] Audit Log tab shows data with pagination
- [ ] Security Management tab shows sessions and stats
- [ ] BU Management tab can create/edit/delete BU
- [ ] Force logout button works
- [ ] Frontend deployed to Vercel
- [ ] Owner email still `owner@insightwos.com`
- [ ] All owner actions logged to audit_log_owner

## ORDER OF OPERATIONS

1. Fix RPC naming mismatch in OwnerDashboard.jsx (5 min)
2. Deploy SQL 100_owner_wave1.sql in Supabase (5 min)
3. Verify RPCs exist in Supabase (2 min)
4. Create OverviewDashboard component (30 min)
5. Create AuditLogViewer component (30 min)
6. Create SecurityManagement component (30 min)
7. Create BusinessUnitManagement component (30 min)
8. Update OwnerDashboard tabs and state (20 min)
9. Test all Wave 1 features (30 min)
10. Deploy to Vercel (5 min)

**Total estimated time:** ~3 hours

## TESTING INSTRUCTIONS

1. Login as owner@insightwos.com
2. Navigate to /owner/dashboard
3. Test each tab:
   - Overview: Stats should load
   - Audit Log: Should show recent actions
   - Security: Should show active sessions
   - BU Management: Should create new BU
4. Check audit_log_owner table for new entries
5. Verify force logout revokes session

## TROUBLESHOOTING

### RPC returns 404
- Check SQL was deployed: `SELECT proname FROM pg_proc WHERE proname LIKE 'owner_%'`
- Check naming matches between frontend and SQL

### Overview stats empty
- Check `get_owner_overview_stats` returns data
- Verify employees_master has data
- Check business_units table has data

### Audit log no data
- Check audit_log_owner table has entries
- Verify recent owner actions were logged
- Check filter is not too restrictive

### BU creation fails
- Check unit_code is unique
- Verify unit_code and unit_name are provided
- Check business_units table constraints

---

**End of Helper Prompt**
