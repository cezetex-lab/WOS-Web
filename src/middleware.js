import { NextResponse } from 'next/server';

// Edge Runtime Ã¢â‚¬â€ runs on Vercel Edge Network (< 50ms)
export const config = {
  matcher: ['/api/:path*', '/worker/:path*', '/dashboard/:path*'],
};

// Rate limit config
const RATE_LIMITS = {
  default: { max: 120, window: 60 },
  api: { max: 60, window: 60 },
  login: { max: 10, window: 300 },
};

function getClientIp(request) {
  return request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

function getRateLimitCategory(pathname) {
  if (pathname.includes('login')) return 'login';
  if (pathname.startsWith('/api/')) return 'api';
  return 'default';
}

export function middleware(request) {
  const { pathname } = request.nextUrl;
  const ip = getClientIp(request);
  const category = getRateLimitCategory(pathname);
  const config = RATE_LIMITS[category];

  // Security headers
  const response = NextResponse.next();
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');

  // Bot protection Ã¢â‚¬â€ block suspicious user agents
  const ua = request.headers.get('user-agent') || '';
  const blocked = ['sqlmap', 'nikto', 'masscan', 'nmap', 'dirbuster', 'gobuster'];
  if (blocked.some((b) => ua.toLowerCase().includes(b))) {
    return new NextResponse('Forbidden', { status: 403 });
  }

  // Rate limit header (actual enforcement via Upstash in API routes)
  response.headers.set('X-RateLimit-Limit', String(config.max));
  response.headers.set('X-RateLimit-Window', String(config.window));

  // CORS for API routes
  if (pathname.startsWith('/api/')) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  }

  return response;
}
