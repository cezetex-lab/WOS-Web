# AGENTS.md — Coding Rules & Conventions

## Overview
This document defines coding standards for insightWOS project based on international industry best practices.

## Tech Stack
- **Frontend**: React 18 + Vite + Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **State**: TanStack React Query (planned)
- **Testing**: Vitest + Testing Library
- **Deployment**: Vercel

---

## 1. File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Components | PascalCase | `DataTable.jsx`, `MetricCard.jsx` |
| Pages | PascalCase | `Home.jsx`, `Admin.jsx` |
| Hooks | camelCase with `use` prefix | `useModuleAccess.js` |
| Utils/Helpers | camelCase | `rate-limiter.js`, `circuit-breaker.js` |
| Constants | UPPER_SNAKE_CASE | `API_TIMEOUT`, `MAX_RETRIES` |
| CSS | kebab-case | `globals.css` |
| SQL Migrations | Sequential number + snake_case | `094_owner_login.sql` |

---

## 2. Code Style Rules

### JavaScript/JSX
- Use `const` by default, `let` when reassignment needed, never `var`
- Use arrow functions for components and callbacks
- Destructure props and state
- Use template literals instead of string concatenation
- No `console.log` in production (use `console.error` for errors only)
- Use early returns to avoid deep nesting

### React Components
- Functional components only (no class components)
- One component per file
- Export default at the end of file
- Use custom hooks for logic reuse
- Avoid inline functions in JSX for performance

### CSS/Tailwind
- Use Tailwind utility classes over custom CSS
- Use design tokens from `tailwind.config.js`
- Follow mobile-first responsive design
- Use `cn()` or template literals for conditional classes

---

## 3. Security Rules (CRITICAL)

### Never Do
- ❌ Store passwords in plain text
- ❌ Expose API keys in client-side code
- ❌ Skip input validation
- ❌ Use `innerHTML` without sanitization
- ❌ Trust user input

### Always Do
- ✅ Use parameterized queries (Supabase RPC)
- ✅ Validate all inputs on server-side
- ✅ Use HTTPS only
- ✅ Implement rate limiting on RPCs
- ✅ Use RLS policies in Supabase
- ✅ Sanitize user input with `sanitizeInput()`

---

## 4. Component Patterns

### Design System Components
```jsx
// Use existing components from design-system
import { Button, Input, GlassCard } from '@/lib/design-system';

// Don't create duplicate components
// Check design-system first before creating new
```

### Page Structure
```jsx
import { PageLayout, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function MyPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState(null);

  if (loading) return <LoadingSpinner text="Memuat data..." />;
  if (!data) return <EmptyState title="Tidak ada data" />;

  return (
    <PageLayout title="Judul" backTo="/previous">
      {/* Content */}
    </PageLayout>
  );
}
```

---

## 5. Data Fetching Rules

### RPC Pattern
```javascript
import { rpc } from '@/lib/supabase-browser';

// Always use the rpc wrapper with rate limiting
const result = await rpc('function_name', { param: value });

// Handle errors
if (!result?.ok) {
  setError(result?.msg || 'Terjadi kesalahan');
  return;
}
```

### State Management
```javascript
// Use useState + useEffect for simple cases
// Use TanStack React Query for complex caching (planned)

const [data, setData] = useState(null);
const [loading, setLoading] = useState(true);
const [error, setError] = useState(null);

useEffect(() => {
  fetchData();
}, []);
```

---

## 6. Error Handling

### Frontend
```javascript
// Use try-catch for async operations
try {
  const result = await rpc('some_function');
  // handle success
} catch (err) {
  console.error('Error:', err);
  setError(err.message);
}
```

### Database (PostgreSQL)
```sql
-- Always return JSONB with ok flag
RETURN jsonb_build_object(
  'ok', true,
  'data', result
);

-- Or on error
RETURN jsonb_build_object(
  'ok', false,
  'msg', 'Error message here'
);
```

---

## 7. Testing Rules

### Unit Tests
- Test utility functions in `src/lib/`
- Test custom hooks
- Aim for 80%+ coverage on critical paths

### Component Tests
- Test user interactions
- Test loading/error states
- Use `@testing-library/react`

---

## 8. Git Commit Convention

```
type(scope): description

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting, semicolons, etc)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Examples
```
feat(payroll): add salary masking for unauthorized users
fix(auth): resolve session guard bypass issue
docs(readme): update deployment instructions
```

---

## 9. Performance Rules

- Use `React.lazy()` for route-level code splitting
- Use `useMemo` and `useCallback` for expensive computations
- Avoid unnecessary re-renders
- Use proper `key` props in lists
- Optimize images with proper sizing

---

## 10. Accessibility Rules

- Use semantic HTML elements
- Add `aria-label` for interactive elements
- Ensure keyboard navigation works
- Maintain proper color contrast (WCAG 2.2 AA)
- Add alt text for images

---

## 11. Environment Variables

### Naming Convention
- Client-side: `VITE_` prefix
- Server-side: No prefix

### Required Variables
```
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
VITE_POSTHOG_KEY (optional)
VITE_GEMINI_API_KEY (optional)
```

---

## 12. SQL Migration Rules

- Sequential numbering: `094_owner_login.sql`
- Use `CREATE OR REPLACE` for idempotency
- Use `DROP IF EXISTS` before creating
- Always add `GRANT EXECUTE` for RPCs
- Use `SECURITY DEFINER` for sensitive functions
- Add RLS policies for new tables

---

## 13. Empty State Rules (MANDATORY)

### ALWAYS show empty state messages when:
- A list/table has 0 items
- A page has no data to display
- A search/filter returns no results
- A module has no records yet

### Pattern:
```jsx
{data.length === 0 ? (
  <div className="text-gray-500 text-sm text-center py-10">
    Belum ada [nama data]
  </div>
) : (
  // render data
)}
```

### Examples:
- `Belum ada integrasi`
- `Belum ada pengumuman`
- `Belum ada changelog`
- `Belum ada ticket`
- `Belum ada data analytics`
- `Tidak ada karyawan`
- `Tidak ada modul`

### Why:
- User needs feedback that data is empty, not a blank page
- Empty state is better UX than mysterious blank space
- Consistent empty state messages across all pages

---

## Review Checklist

Before submitting code:
- [ ] No `console.log` in production code
- [ ] Input validation on all forms
- [ ] Error handling for async operations
- [ ] Loading states for data fetching
- [ ] Empty state messages when data is empty (e.g., 'Belum ada data', 'Tidak ada item')
- [ ] Responsive design works on mobile
- [ ] Accessibility labels present
- [ ] No hardcoded secrets
- [ ] SQL migrations are idempotent
