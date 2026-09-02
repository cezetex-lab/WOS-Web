# INCIDENT RESPONSE PLAN
## INSIGHTWOS V6 - Security Incident Procedures
**Created:** September 3, 2026 | **Owner:** System Administrator

---

## INCIDENT CLASSIFICATION

| Severity | Description | Response Time | Example |
|----------|-------------|:-------------:|---------|
| P0 CRITICAL | Data breach, system compromise | 1 hour | Unauthorized admin access, data theft |
| P1 HIGH | Service outage, data integrity risk | 4 hours | Supabase down, login system failure |
| P2 MEDIUM | Feature degradation, security concern | 24 hours | Cache failure, slow performance |
| P3 LOW | Minor issue, cosmetic bug | 72 hours | UI glitch, non-critical error |

---

## ESCALATION MATRIX

| Severity | First Responder | Escalation | Communication |
|----------|----------------|------------|---------------|
| P0 | DevOps/Lead Dev | CTO/CEO | All stakeholders |
| P1 | Dev Team | DevOps | Internal team |
| P2 | Dev Team | Lead Dev | Team chat |
| P3 | Assigned Dev | Lead Dev | Ticket system |

---

## RESPONSE PROCEDURES

### P0: Data Breach / System Compromise

1. **CONTAIN (0-15 min)**
   - Revoke all active sessions: Supabase Dashboard > Auth > Users > Sign Out All
   - Block suspicious IPs at Cloudflare
   - Enable maintenance mode if needed

2. **ASSESS (15-60 min)**
   - Check security_audit_log table for breach scope
   - Check login_attempts for unauthorized access
   - Review RLS policies for data exposure

3. **NOTIFY (within 72 hours for GDPR)**
   - Document incident timeline
   - Notify affected users if personal data exposed
   - File regulatory report if required

4. **RECOVER**
   - Restore from latest backup if data compromised
   - Rotate all API keys and secrets
   - Patch vulnerability

5. **REVIEW**
   - Post-incident analysis within 1 week
   - Update security procedures

### P1: Service Outage

1. **IDENTIFY** (0-10 min)
   - Check service status pages: Supabase, Vercel, Upstash
   - Determine scope: all users or subset

2. **COMMUNICATE** (10-30 min)
   - Notify users via status channel
   - Enable maintenance page if needed

3. **MITIGATE**
   - If Supabase down: switch to Neon standby
   - If Vercel down: switch DNS to Cloudflare Pages
   - If Upstash down: automatic fallback (no action needed)

---

## GDPR BREACH NOTIFICATION (72-hour requirement)

If personal data of EU residents is compromised:

1. **Within 24 hours:** Internal assessment + documentation
2. **Within 72 hours:** Notify supervisory authority
3. **Without delay:** Notify affected individuals if high risk

Template notification:
> We have detected a security incident that may have affected your personal data.
> The incident occurred on [DATE] and was discovered on [DATE].
> Affected data: [DESCRIPTION]
> Actions taken: [DESCRIPTION]
> Contact: [SECURITY EMAIL]

---

## EVIDENCE PRESERVATION

For security incidents, preserve:
1. security_audit_log entries
2. login_attempts records
3. Supabase audit logs (Dashboard > Logs)
4. Vercel function logs
5. Browser console screenshots
6. Timeline of events

---

## CONTACTS

| Role | Contact | When |
|------|---------|------|
| System Admin | [ADMIN_EMAIL] | All incidents |
| Supabase Support | support@supabase.com | Database issues |
| Vercel Support | support@vercel.com | Hosting issues |
| Legal | [LEGAL_EMAIL] | GDPR breach |

---

**Review:** Quarterly | **Last Updated:** September 3, 2026
