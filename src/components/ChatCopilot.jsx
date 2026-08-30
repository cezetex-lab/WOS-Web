// ============================================================
// ChatCopilot.jsx — AI Copilot Chat UI
// Floating chat widget with RAG-powered responses
// ============================================================

import { useState, useRef, useEffect, useCallback } from 'react';
import { rpc } from '@/lib/supabase-browser';

// ── API call to AI Copilot Edge Function ──
async function askCopilot(message, conversationHistory = [], context = 'general') {
  const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
  const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

  const res = await fetch(`${SUPABASE_URL}/functions/v1/ai-copilot`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify({ message, conversationHistory, context }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: 'Network error' }));
    throw new Error(err.error || `HTTP ${res.status}`);
  }

  return res.json();
}

// ── Quick action suggestions ──
const QUICK_ACTIONS = [
  { label: 'Ringkasan KPI', icon: '📊', message: 'Bagaimana ringkasan KPI karyawan bulan ini? Siapa yang perlu perhatian?', context: 'kpi' },
  { label: 'Cek Payroll', icon: '💰', message: 'Tolong breakdown payroll bulan ini. Ada anomali?', context: 'payroll' },
  { label: 'Kehadiran', icon: '📋', message: 'Bagaimana kondisi kehadiran karyawan minggu ini? Ada yang sering telat?', context: 'attendance' },
  { label: 'Kebijakan', icon: '📖', message: 'Apa kebijakan cuti tahunan dan cara pengajuannya?', context: 'policy' },
];

// ── Markdown-like renderer (simple) ──
function renderMessage(text) {
  if (!text) return null;

  // Bold
  let html = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
  // Italic
  html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
  // Code blocks
  html = html.replace(/```([\s\S]*?)```/g, '<pre class="bg-slate-900/60 rounded-lg p-3 my-2 text-xs overflow-x-auto font-mono text-emerald-400"><code>$1</code></pre>');
  // Inline code
  html = html.replace(/`([^`]+)`/g, '<code class="bg-slate-900/60 px-1.5 py-0.5 rounded text-sky-400 text-xs">$1</code>');
  // Lists
  html = html.replace(/^- (.*$)/gm, '<li class="ml-4 list-disc text-slate-300">$1</li>');
  html = html.replace(/^(\d+)\. (.*$)/gm, '<li class="ml-4 list-decimal text-slate-300">$2</li>');
  // Line breaks
  html = html.replace(/\n/g, '<br/>');

  return html;
}

// ── Typing indicator ──
function TypingIndicator() {
  return (
    <div className="flex items-center gap-2 px-4 py-3">
      <div className="flex gap-1">
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
      </div>
      <span className="text-xs text-slate-400">AI sedang berpikir...</span>
    </div>
  );
}

// ── Welcome screen ──
function WelcomeScreen({ onSelect }) {
  return (
    <div className="flex flex-col items-center justify-center py-6 px-4">
      <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-3xl mb-4 shadow-lg shadow-sky-500/20">
        🤖
      </div>
      <h3 className="text-white font-bold text-lg mb-1">AI Copilot</h3>
      <p className="text-slate-400 text-sm text-center mb-6">
        Asisten AI untuk insightWOS.<br />
        Tanya apa saja tentang data HR, KPI, kebijakan, dll.
      </p>

      <div className="grid grid-cols-2 gap-2 w-full">
        {QUICK_ACTIONS.map((action, i) => (
          <button
            key={i}
            onClick={() => onSelect(action.message, action.context)}
            className="flex items-center gap-2 p-3 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 border border-slate-700/50 hover:border-sky-500/30 transition-all text-left"
          >
            <span className="text-xl">{action.icon}</span>
            <span className="text-sm text-slate-300">{action.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ── Message bubble ──
function MessageBubble({ msg, isUser }) {
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-3`}>
      <div className={`flex gap-2 max-w-[85%] ${isUser ? 'flex-row-reverse' : ''}`}>
        {/* Avatar */}
        {!isUser && (
          <div className="w-7 h-7 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-sm flex-shrink-0 mt-1">
            🤖
          </div>
        )}

        {/* Bubble */}
        <div className={`rounded-2xl px-4 py-2.5 ${
          isUser
            ? 'bg-sky-600/80 text-white rounded-br-md'
            : 'bg-slate-800/80 text-slate-200 rounded-bl-md border border-slate-700/50'
        }`}>
          {isUser ? (
            <p className="text-sm">{msg.text}</p>
          ) : (
            <div
              className="text-sm leading-relaxed"
              dangerouslySetInnerHTML={{ __html: renderMessage(msg.text) }}
            />
          )}

          {/* Sources */}
          {!isUser && msg.sources?.length > 0 && (
            <div className="mt-2 pt-2 border-t border-slate-700/50">
              <p className="text-[10px] text-slate-500 mb-1">📚 Sumber:</p>
              <div className="flex flex-wrap gap-1">
                {msg.sources.map((s, i) => (
                  <span key={i} className="text-[10px] bg-slate-700/50 text-slate-400 px-2 py-0.5 rounded-full">
                    {s.title} ({Math.round(s.similarity * 100)}%)
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Timestamp */}
          <p className={`text-[10px] mt-1 ${isUser ? 'text-sky-200/50' : 'text-slate-500'}`}>
            {msg.time}
          </p>
        </div>
      </div>
    </div>
  );
}

// ── Main ChatCopilot component ──
export default function ChatCopilot({ context = 'general' }) {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [unread, setUnread] = useState(0);
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isLoading]);

  // Focus input when opened
  useEffect(() => {
    if (isOpen) {
      setUnread(0);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [isOpen]);

  // Send message
  const handleSend = useCallback(async (text = input, msgContext = context) => {
    const trimmed = text.trim();
    if (!trimmed || isLoading) return;

    const userMsg = {
      id: Date.now(),
      text: trimmed,
      isUser: true,
      time: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      // Build conversation history for context
      const history = messages.slice(-10).map(m => ({
        role: m.isUser ? 'user' : 'assistant',
        content: m.text,
      }));

      const result = await askCopilot(trimmed, history, msgContext);

      const botMsg = {
        id: Date.now() + 1,
        text: result.message,
        isUser: false,
        sources: result.sources || [],
        time: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages(prev => [...prev, botMsg]);

      if (!isOpen) setUnread(prev => prev + 1);
    } catch (error) {
      console.error('Copilot error:', error);
      const errorMsg = {
        id: Date.now() + 1,
        text: `❌ Maaf, terjadi kesalahan: ${error.message}\n\nCoba lagi dalam beberapa saat.`,
        isUser: false,
        time: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages(prev => [...prev, errorMsg]);
    } finally {
      setIsLoading(false);
    }
  }, [input, messages, isLoading, isOpen, context]);

  // Handle quick action
  const handleQuickAction = useCallback((message, actionContext) => {
    handleSend(message, actionContext);
  }, [handleSend]);

  // Handle key press
  const handleKeyDown = useCallback((e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }, [handleSend]);

  return (
    <>
      {/* ── Floating Action Button ── */}
      {!isOpen && (
        <button
          onClick={() => setIsOpen(true)}
          className="fixed bottom-20 right-4 z-50 w-14 h-14 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-2xl shadow-lg shadow-sky-500/30 hover:shadow-sky-500/50 transition-all hover:scale-105 active:scale-95"
          aria-label="AI Copilot"
        >
          🤖
          {unread > 0 && (
            <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full flex items-center justify-center text-[10px] text-white font-bold">
              {unread > 9 ? '9+' : unread}
            </span>
          )}
        </button>
      )}

      {/* ── Chat Panel ── */}
      {isOpen && (
        <div className="fixed inset-x-0 bottom-0 z-50 sm:inset-x-auto sm:right-4 sm:bottom-20 sm:w-[380px] sm:max-h-[560px] h-[85vh] sm:h-auto flex flex-col bg-slate-900/95 backdrop-blur-xl border-t sm:border sm:rounded-2xl border-slate-700/50 shadow-2xl shadow-black/40 overflow-hidden animate-in slide-in-from-bottom duration-300">
          
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 bg-gradient-to-r from-sky-600/20 to-indigo-600/20 border-b border-slate-700/50">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-lg">
                🤖
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">AI Copilot</h3>
                <p className="text-[10px] text-slate-400">insightWOS Assistant</p>
              </div>
            </div>
            <button
              onClick={() => setIsOpen(false)}
              className="w-8 h-8 rounded-full bg-slate-800 hover:bg-slate-700 flex items-center justify-center text-slate-400 hover:text-white transition-colors"
            >
              ✕
            </button>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-4 py-3 space-y-1" style={{ maxHeight: 'calc(85vh - 140px)' }}>
            {messages.length === 0 && !isLoading ? (
              <WelcomeScreen onSelect={handleQuickAction} />
            ) : (
              <>
                {messages.map(msg => (
                  <MessageBubble key={msg.id} msg={msg} isUser={msg.isUser} />
                ))}
                {isLoading && <TypingIndicator />}
                <div ref={messagesEndRef} />
              </>
            )}
          </div>

          {/* Quick actions (shown when empty or few messages) */}
          {messages.length <= 2 && !isLoading && (
            <div className="px-4 pb-2">
              <div className="flex gap-1.5 overflow-x-auto pb-2 scrollbar-hide">
                {QUICK_ACTIONS.map((action, i) => (
                  <button
                    key={i}
                    onClick={() => handleQuickAction(action.message, action.context)}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-slate-800/80 hover:bg-sky-600/20 border border-slate-700/50 hover:border-sky-500/30 text-xs text-slate-400 hover:text-sky-400 transition-all whitespace-nowrap flex-shrink-0"
                  >
                    <span>{action.icon}</span>
                    <span>{action.label}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Input */}
          <div className="px-3 pb-3 pt-1 border-t border-slate-700/50">
            <div className="flex items-center gap-2 bg-slate-800/80 rounded-xl border border-slate-700/50 focus-within:border-sky-500/50 transition-colors">
              <input
                ref={inputRef}
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Tanya AI Copilot..."
                disabled={isLoading}
                className="flex-1 bg-transparent px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none"
              />
              <button
                onClick={() => handleSend()}
                disabled={!input.trim() || isLoading}
                className="w-9 h-9 rounded-lg bg-sky-600 hover:bg-sky-500 disabled:bg-slate-700 disabled:text-slate-500 flex items-center justify-center text-white transition-colors mr-1"
              >
                {isLoading ? (
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <span className="text-sm">➤</span>
                )}
              </button>
            </div>
            <p className="text-[9px] text-slate-600 text-center mt-1.5">
              AI Copilot — jawaban berdasarkan data & kebijakan perusahaan (Gemini)
            </p>
          </div>
        </div>
      )}
    </>
  );
}
