// ============================================================
// Layout.jsx — Global layout with AI Copilot
// ============================================================

import ChatCopilot from '@/components/ChatCopilot';

export function Layout({ children }) {
  return (
    <main className="min-h-screen max-w-7xl mx-auto">
      {children}
      {/* AI Copilot — floating on all pages */}
      <ChatCopilot />
    </main>
  );
}
