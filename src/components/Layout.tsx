// ============================================================
// Layout.jsx — Global layout with AI Copilot
// ============================================================

import ChatCopilot from '@/components/ChatCopilot';

export function Layout({ children }) {
  return (
    <div className="min-h-screen max-w-7xl mx-auto">
      {/* Skip to main content — for keyboard/screen reader users */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[9999] focus:bg-teal-500 focus:text-white focus:px-4 focus:py-2 focus:rounded-lg focus:font-semibold"
      >
        Langsung ke konten utama
      </a>
      <main id="main-content" tabIndex={-1} className="min-h-screen">
        {children}
      </main>
      {/* AI Copilot — floating on all pages */}
      <ChatCopilot />
    </div>
  );
}
