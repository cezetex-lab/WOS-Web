// ============================================================
// OrgSubtree.jsx — #15 Subtree View Rekursif
// RPC: admin_get_org_structure
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, LoadingSpinner, EmptyState, Avatar, Badge, Input, Button
} from '../../lib/design-system';

export default function OrgSubtree() {
  const [loading, setLoading] = useState(true);
  const [orgData, setOrgData] = useState([]);
  const [tree, setTree] = useState(null);
  const [searchNrp, setSearchNrp] = useState('');
  const [expanded, setExpanded] = useState(new Set());

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_org_structure');
      const items = result?.data || result || [];
      setOrgData(Array.isArray(items) ? items : []);
    } catch (err) {
      const { data } = await supabase.from('hr_org').select('*');
      setOrgData(data || []);
    }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Build tree from flat data
  useEffect(() => {
    if (orgData.length === 0) return;
    const map = {};
    orgData.forEach(item => {
      map[item.nrp] = { ...item, children: [] };
    });
    let root = null;
    orgData.forEach(item => {
      if (item.atasan_nrp && map[item.atasan_nrp]) {
        map[item.atasan_nrp].children.push(map[item.nrp]);
      } else if (!item.atasan_nrp) {
        root = map[item.nrp];
      }
    });
    // If no root, take first node
    if (!root && orgData.length > 0) root = map[orgData[0].nrp];
    setTree(root);
  }, [orgData]);

  // Expand all by default on load
  useEffect(() => {
    if (orgData.length > 0) {
      setExpanded(new Set(orgData.map(d => d.nrp)));
    }
  }, [orgData]);

  const toggleExpand = (nrp) => {
    setExpanded(prev => {
      const next = new Set(prev);
      if (next.has(nrp)) next.delete(nrp);
      else next.add(nrp);
      return next;
    });
  };

  const expandAll = () => setExpanded(new Set(orgData.map(d => d.nrp)));
  const collapseAll = () => setExpanded(new Set());

  if (loading) return <PageLayout backTo="/admin" title="Subtree Organisasi"><LoadingSpinner text="Memuat struktur..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="Subtree Organisasi" subtitle={`${orgData.length} node`}>
      {/* ── CONTROLS ── */}
      <div className="flex items-center gap-2 mb-4">
        <Button color="teal" size="sm" onClick={expandAll}>📖 Expand All</Button>
        <Button color="ghost" size="sm" onClick={collapseAll}>📕 Collapse All</Button>
        <Button color="blue" size="sm" onClick={() => {
          if (searchNrp) {
            setExpanded(prev => new Set([...prev, searchNrp]));
            const el = document.getElementById(`node-${searchNrp}`);
            if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }}>🔍 Cari</Button>
      </div>
      <div className="mb-4">
        <Input placeholder="Cari NRP..." value={searchNrp} onChange={(e) => setSearchNrp(e.target.value)} icon="🔍" />
      </div>

      {/* ── TREE ── */}
      <GlassCard accent="blue">
        {tree ? (
          <TreeNode
            node={tree}
            level={0}
            expanded={expanded}
            toggleExpand={toggleExpand}
            searchNrp={searchNrp}
          />
        ) : (
          <EmptyState icon="🏢" title="Tidak ada data organisasi" subtitle="Jalankan migration 027 terlebih dahulu" />
        )}
      </GlassCard>

      {/* ── STATS ── */}
      <GlassCard title="Statistik" icon="📊" accent="teal" className="mt-4">
        <div className="grid grid-cols-3 gap-2 text-center">
          <div className="p-2 bg-slate-900/40 rounded-xl">
            <div className="text-lg font-bold text-white">{orgData.length}</div>
            <div className="text-[10px] text-slate-400">Total Node</div>
          </div>
          <div className="p-2 bg-slate-900/40 rounded-xl">
            <div className="text-lg font-bold text-teal-400">{orgData.filter(d => !d.atasan_nrp).length || 1}</div>
            <div className="text-[10px] text-slate-400">Root Nodes</div>
          </div>
          <div className="p-2 bg-slate-900/40 rounded-xl">
            <div className="text-lg font-bold text-blue-400">{calcDepth(tree)}</div>
            <div className="text-[10px] text-slate-400">Max Depth</div>
          </div>
        </div>
      </GlassCard>
    </PageLayout>
  );
}

// ── TREE NODE ──
function TreeNode({ node, level, expanded, toggleExpand, searchNrp }) {
  if (!node) return null;
  const hasChildren = node.children && node.children.length > 0;
  const isExpanded = expanded.has(node.nrp);
  const isHighlighted = searchNrp && node.nrp === searchNrp;
  const indent = level * 24;

  return (
    <div id={`node-${node.nrp}`}>
      <div
        className={`flex items-center gap-2 py-2 px-2 rounded-xl mb-1 transition-all cursor-pointer
          ${isHighlighted ? 'bg-teal-500/20 border border-teal-500/30' : 'hover:bg-white/3 border border-transparent'}
        `}
        style={{ paddingLeft: `${indent + 8}px` }}
        onClick={() => hasChildren && toggleExpand(node.nrp)}
      >
        {/* Expand icon */}
        {hasChildren ? (
          <span className="text-xs text-slate-500 w-4 text-center">
            {isExpanded ? '▼' : '▶'}
          </span>
        ) : (
          <span className="text-xs text-slate-700 w-4 text-center">•</span>
        )}

        {/* Avatar + Name */}
        <Avatar name={node.nama || node.nrp} size="sm" />
        <div className="flex-1 min-w-0">
          <p className="text-xs font-bold text-white truncate">{node.nama || node.nrp}</p>
          <p className="text-[10px] text-slate-500">{node.nrp} • {node.posisi || node.role_level || '-'}</p>
        </div>

        {/* Children count */}
        {hasChildren && (
          <Badge status={`${node.children.length} bawahan`} type="info" />
        )}
      </div>

      {/* Children */}
      {hasChildren && isExpanded && (
        <div>
          {node.children.map(child => (
            <TreeNode
              key={child.nrp}
              node={child}
              level={level + 1}
              expanded={expanded}
              toggleExpand={toggleExpand}
              searchNrp={searchNrp}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ── HELPER: Calculate tree depth ──
function calcDepth(node) {
  if (!node || !node.children || node.children.length === 0) return 0;
  return 1 + Math.max(...node.children.map(calcDepth));
}
