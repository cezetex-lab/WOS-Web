interface ChatCopilotProps { open?: boolean; onClose?: () => void; context?: string; }

// ChatCopilot.jsx — AI Copilot Chat UI (DOMPurify, role-isolated, DB data list)
import { useState, useRef, useEffect, useCallback } from 'react';
import { callEdgeFunction } from '@/lib/edge-functions';
import DOMPurify from 'dompurify';

function askCopilot(message: string, conversationHistory: Array<{ role: string; content: string }> = [], context = 'general') {
  return callEdgeFunction(
    'ai-copilot',
    { message, conversationHistory, context },
    { throwOnError: true }
  );
}

// Safe HTML renderer — DOMPurify sanitizes all output
function renderMessage(text: string): string {
  if (!text) return '';
  let html = text
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/```([\s\S]*?)```/g, '<pre class="bg-slate-900/60 rounded-lg p-3 my-2 text-xs overflow-x-auto font-mono text-emerald-400"><code>$1</code></pre>')
    .replace(/`([^`]+)`/g, '<code class="bg-slate-900/60 px-1.5 py-0.5 rounded text-sky-400 text-xs">$1</code>')
    .replace(/^- (.*$)/gm, '<li class="ml-4 list-disc text-slate-300">$1</li>')
    .replace(/^(\d+)\. (.*$)/gm, '<li class="ml-4 list-decimal text-slate-300">$2</li>')
    .replace(/\n/g, '<br/>');
  return DOMPurify.sanitize(html);
}

function TypingIndicator() {
  return (
    <div className="flex items-center gap-2 px-4 py-3">
      <div className="flex gap-1">
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
        <span className="w-2 h-2 bg-sky-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
      </div>
      <span className="text-xs text-slate-400">Mencari data...</span>
    </div>
  );
}

interface DbDataItem {
  category?: string;
  data?: Record<string, unknown>;
  raw?: string;
}

// DB data list component — shows structured data after AI response
function DbDataList({ dbData }: { dbData?: DbDataItem[] }) {
  if (!dbData || dbData.length === 0) return null;
  return (
    <div className="mt-3 pt-3 border-t border-slate-700/50">
      <p className="text-[11px] text-slate-500 mb-2">📋 Data dari database:</p>
      {dbData.map((item, i) => (
        <div key={i} className="mb-2 p-2 bg-slate-900/40 rounded-lg">
          <p className="text-xs font-semibold text-sky-400 mb-1">{item.category}</p>
          {item.data && Object.keys(item.data).length > 0 ? (
            <div className="space-y-0.5">
              {Object.entries(item.data).map(([k, v]: [string, unknown], j: number) => (
                <div key={j} className="flex gap-2 text-[11px]">
                  <span className="text-slate-500 min-w-[80px]">{k}:</span>
                  <span className="text-slate-300">{String(v)}</span>
                </div>
              ))}
            </div>
          ) : item.raw ? (
            <p className="text-[11px] text-slate-400 whitespace-pre-wrap">{item.raw}</p>
          ) : null}
        </div>
      ))}
    </div>
  );
}

interface ChatMessage {
  id: number;
  text: string;
  isUser: boolean;
  time: string;
  sources?: Array<{ title: string }>;
  dbData?: DbDataItem[];
  rateLimit?: { warning?: boolean; warning_msg?: string; limit?: number; remaining?: number } | null;
}

function MessageBubble({ msg, isUser }: { msg: ChatMessage; isUser: boolean }) {
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-3`}>
      <div className={`flex gap-2 max-w-[85%] ${isUser ? 'flex-row-reverse' : ''}`}>
        {!isUser && (
          <div className="w-7 h-7 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-sm flex-shrink-0 mt-1">
            🤖
          </div>
        )}
        <div className={`rounded-2xl px-4 py-2.5 ${
          isUser
            ? 'bg-sky-600/80 text-white rounded-br-md'
            : 'bg-slate-800/80 text-slate-200 rounded-bl-md border border-slate-700/50'
        }`}>
          {isUser ? (
            <p className="text-sm">{msg.text}</p>
          ) : (
            <>
              <div
                className="text-sm leading-relaxed"
                dangerouslySetInnerHTML={{ __html: renderMessage(msg.text) }}
              />
              <DbDataList dbData={msg.dbData} />
              {msg.rateLimit?.warning && (
                <div className="mt-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 rounded-lg">
                  <p className="text-[11px] text-amber-400">
                    ⚠️ {msg.rateLimit.warning_msg}
                  </p>
                </div>
              )}
            </>
          )}
          {!isUser && msg.sources && msg.sources.length > 0 && (
            <div className="mt-2 pt-2 border-t border-slate-700/50">
              <p className="text-[11px] text-slate-500 mb-1">📚 Sumber:</p>
              <div className="flex flex-wrap gap-1">
                {msg.sources.map((s: { title: string }, i: number) => (
                  <span key={i} className="text-[11px] bg-slate-700/50 text-slate-400 px-2 py-0.5 rounded-full">
                    {s.title}
                  </span>
                ))}
              </div>
            </div>
          )}
          <p className={`text-[11px] mt-1 ${isUser ? 'text-sky-200/50' : 'text-slate-500'}`}>
            {msg.time}
          </p>
        </div>
      </div>
    </div>
  );
}

export default function ChatCopilot({ context = 'general' }: ChatCopilotProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [unread, setUnread] = useState(0);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isLoading]);

  useEffect(() => {
    if (isOpen) {
      setUnread(0);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [isOpen]);

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
      const history = messages.slice(-10).map(m => ({
        role: m.isUser ? 'user' : 'assistant',
        content: m.text,
      }));

      const result = await askCopilot(trimmed, history, msgContext);

      const botMsg: ChatMessage = {
        id: Date.now() + 1,
        text: String(result.message ?? ''),
        isUser: false,
        sources: Array.isArray(result.sources) ? result.sources : [],
        dbData: Array.isArray(result.dbData) ? result.dbData : [],
        rateLimit: result.rateLimit ?? null,
        time: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages(prev => [...prev, botMsg]);
      if (!isOpen) setUnread(prev => prev + 1);
    } catch (error: unknown) {
      const errorMsg: ChatMessage = {
        id: Date.now() + 1,
        text: `Maaf, terjadi kesalahan: ${error instanceof Error ? error.message : String(error)}\n\nCoba lagi dalam beberapa saat.`,
        isUser: false,
        time: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages(prev => [...prev, errorMsg]);
    } finally {
      setIsLoading(false);
    }
  }, [input, messages, isLoading, isOpen, context]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }, [handleSend]);

  return (
    <>
      {!isOpen && (
        <button
          onClick={() => setIsOpen(true)}
          className="fixed bottom-20 right-4 z-50 w-14 h-14 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-2xl shadow-lg shadow-sky-500/30 hover:shadow-sky-500/50 transition-all hover:scale-105 active:scale-95"
          aria-label="AI Copilot"
        >
          🤖
          {unread > 0 && (
            <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full flex items-center justify-center text-[11px] text-white font-bold">
              {unread > 9 ? '9+' : unread}
            </span>
          )}
        </button>
      )}

      {isOpen && (
        <div className="fixed inset-x-0 bottom-0 z-50 sm:inset-x-auto sm:right-4 sm:bottom-20 sm:w-[380px] sm:max-h-[560px] h-[85vh] sm:h-auto flex flex-col bg-slate-900/95 backdrop-blur-xl border-t sm:border sm:rounded-2xl border-slate-700/50 shadow-2xl shadow-black/40 overflow-hidden animate-in slide-in-from-bottom duration-300">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 bg-gradient-to-r from-sky-600/20 to-indigo-600/20 border-b border-slate-700/50">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-lg">🤖</div>
              <div>
                <h3 className="text-sm font-bold text-white">AI Copilot</h3>
                <p className="text-[11px] text-slate-400">insightWOS Assistant</p>
              </div>
            </div>
            <button onClick={() => setIsOpen(false)} className="w-8 h-8 rounded-full bg-slate-800 hover:bg-slate-700 flex items-center justify-center text-slate-400 hover:text-white transition-colors">✕</button>
          </div>

          {/* Messages — blank page when empty */}
          <div className="flex-1 overflow-y-auto px-4 py-3 space-y-1" style={{ maxHeight: 'calc(85vh - 140px)' }}>
            {messages.length === 0 && !isLoading ? (
              <div className="flex flex-col items-center justify-center h-full py-12">
                <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-2xl mb-3">🤖</div>
                <p className="text-slate-500 text-sm text-center">Tanya apa saja tentang data HR</p>
              </div>
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

          {/* Input */}
          <div className="px-3 pb-3 pt-1 border-t border-slate-700/50">
            <div className="flex items-center gap-2 bg-slate-800/80 rounded-xl border border-slate-700/50 focus-within:border-sky-500/50 transition-colors">
              <input
                ref={inputRef}
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Cari data HR..."
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
            <p className="text-[11px] text-slate-600 text-center mt-1.5">
              Data terisolasi berdasarkan role Anda
              {messages.length > 0 && (messages[messages.length - 1]?.rateLimit?.limit ?? 0) > 0 && (
                <span className="block text-slate-500">
                  Sisa {messages[messages.length - 1]?.rateLimit?.remaining}/{messages[messages.length - 1]?.rateLimit?.limit} query hari ini
                </span>
              )}
            </p>
          </div>
        </div>
      )}
    </>
  );
}
