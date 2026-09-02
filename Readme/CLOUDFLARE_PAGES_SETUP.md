# Cloudflare Pages Deployment Guide
# INSIGHTWOS V6 — Backup Hosting

## Setup Steps

### 1. Create Cloudflare Account
- Go to https://dash.cloudflare.com/sign-up
- Create free account

### 2. Connect GitHub Repo
- Go to Workers & Pages > Create > Pages > Connect to Git
- Select repository: cezetex-lab/WOS-Web
- Branch: migrasi-vite

### 3. Configure Build Settings
- Framework preset: Vite
- Build command: npm run build
- Build output directory: dist
- Node.js version: 18

### 4. Environment Variables
- VITE_SUPABASE_URL = (from .env)
- VITE_SUPABASE_ANON_KEY = (from .env)

### 5. Deploy
- Push to migrasi-vite branch
- Cloudflare auto-deploys
- Access at: insightwos.pages.dev

## DNS Failover Strategy

Primary: insightwos.vercel.app (TTL: 300)
Backup:  insightwos.pages.dev  (TTL: 300)

## Failover Procedure

If Vercel down:
1. Go to DNS provider
2. Change CNAME from Vercel to Cloudflare Pages
3. Wait 5 minutes for propagation
4. Verify app works

## Cost: $0/month (unlimited bandwidth on free tier)
