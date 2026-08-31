// ForumDiskusi.jsx — Forum diskusi karyawan
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, Badge, Button, LoadingSpinner, EmptyState, Input } from '../../lib/design-system';

export default function ForumDiskusi() {
  const [loading, setLoading] = useState(true);
  const [posts, setPosts] = useState([]);
  const [selected, setSelected] = useState(null);
  const [showNew, setShowNew] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newContent, setNewContent] = useState('');
  const [newCategory, setNewCategory] = useState('Umum');
  const [replyContent, setReplyContent] = useState('');

  const nrp = localStorage.getItem('wos_nrp') || JSON.parse(sessionStorage.getItem('wos_user') || '{}')?.nrp || 'NRP001';

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_forum_posts');
      setPosts(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const createPost = async () => {
    if (!newTitle.trim() || !newContent.trim()) return;
    try {
      await rpc('create_forum_post', { p_nrp: nrp, p_title: newTitle, p_content: newContent, p_category: newCategory });
      setShowNew(false);
      setNewTitle('');
      setNewContent('');
      fetchData();
    } catch (e) { console.error(e); }
  };

  const sendReply = async () => {
    if (!replyContent.trim() || !selected) return;
    try {
      await rpc('reply_forum_post', { p_post_id: selected.id, p_nrp: nrp, p_content: replyContent });
      setReplyContent('');
      fetchData();
    } catch (e) { console.error(e); }
  };

  const categories = ['Umum', 'KPI', 'Kebijakan', 'Saran', 'K3'];

  if (loading) return <PageLayout backTo="/worker" title="Forum"><LoadingSpinner text="Memuat forum..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="💬 Forum Diskusi" subtitle={`${posts.length} diskusi`}>
      <Button color="blue" className="w-full mb-4" onClick={() => setShowNew(!showNew)}>
        {showNew ? '✕ Batal' : '✏️ Buat Diskusi Baru'}
      </Button>

      {showNew && (
        <GlassCard accent="blue" className="mb-4">
          <div className="space-y-3">
            <Input label="Judul" value={newTitle} onChange={setNewTitle} placeholder="Judul diskusi..." />
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Kategori</label>
              <div className="flex gap-1 flex-wrap">
                {categories.map(c => (
                  <button key={c} onClick={() => setNewCategory(c)} className={`text-[10px] px-3 py-1 rounded-full transition-all ${newCategory === c ? 'bg-blue-500 text-white' : 'bg-slate-800 text-slate-400'}`}>{c}</button>
                ))}
              </div>
            </div>
            <textarea value={newContent} onChange={e => setNewContent(e.target.value)} className="w-full bg-slate-800/50 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:border-blue-500/50 focus:outline-none resize-none" rows={4} placeholder="Tulis diskusi..." />
            <Button color="green" onClick={createPost} className="w-full">📤 Kirim</Button>
          </div>
        </GlassCard>
      )}

      <div className="space-y-2">
        {posts.map(post => (
          <GlassCard key={post.id} accent={post.pinned ? 'yellow' : 'blue'} className={`cursor-pointer hover:border-blue-500/30 transition-all ${selected?.id === post.id ? 'ring-1 ring-blue-500/30' : ''}`} onClick={() => setSelected(selected?.id === post.id ? null : post)}>
            {post.pinned && <span className="text-[10px] text-yellow-400 mb-1 block">📌 Pinned</span>}
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-xs font-bold flex-shrink-0">
                {(post.nrp || '?')[0]}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="text-sm font-semibold text-white truncate">{post.title}</h3>
                <p className="text-[10px] text-slate-300 mt-1 line-clamp-2">{post.content}</p>
                <div className="flex items-center gap-3 mt-2">
                  <Badge status={post.category || 'Umum'} type="info" />
                  <span className="text-[10px] text-slate-400">💬 {post.replies_count || 0}</span>
                  <span className="text-[10px] text-slate-400">👍 {post.likes_count || 0}</span>
                  <span className="text-[10px] text-slate-500">{post.created_at ? new Date(post.created_at).toLocaleDateString('id-ID') : '-'}</span>
                </div>
              </div>
            </div>

            {selected?.id === post.id && (
              <div className="mt-3 pt-3 border-t border-white/10">
                <p className="text-xs text-slate-300 mb-3 whitespace-pre-wrap">{post.content}</p>
                <div className="flex gap-2">
                  <input value={replyContent} onChange={e => setReplyContent(e.target.value)} className="flex-1 bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none" placeholder="Balas..." onClick={e => e.stopPropagation()} />
                  <Button size="sm" color="blue" onClick={(e) => { e.stopPropagation(); sendReply(); }}>💬</Button>
                </div>
              </div>
            )}
          </GlassCard>
        ))}
        {posts.length === 0 && <EmptyState title="Belum ada diskusi" subtitle="Mulai diskusi pertama!" icon="💬" />}
      </div>
    </PageLayout>
  );
}
