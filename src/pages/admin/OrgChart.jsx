// ============================================================
// OrgChart.jsx — #13 Struktur Organisasi Interaktif
// Visual hierarchy tree — NOT DetailPageFactory
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, LoadingSpinner, EmptyState, Avatar,
  Badge, Input, Button, StatItem
} from '../../lib/design-system';

export default function OrgChart() {
  const [loading, setLoading] = useState(true);
  const [orgData, setOrgData] = useState([]);
  const [tree, setTree] = useState(null);
  const [searchNrp, setSearchNrp] = useState('');
  const [selectedNode, setSelectedNode] = useState(null);
  const [businessUnit, setBusinessUnit] = useState('ALL');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_org_structure');
      const items = result?.data || result || [];
      setOrgData(Array.isArray(items) ? items : []);
    } catch (err) {
      console.error('OrgChart RPC failed:', err);
      setOrgData([]);
    }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Build tree from flat data
  useEffect(() => {
    if (orgData.length === 0) return;
    
    // Enrich with employee data
    const enriched = orgData.map(item => {
      const emp = orgData.find(e => e.nrp === item.nrp) || item;
      return { ...item, nama: emp.nama || item.nama, posisi: emp.posisi || item.posisi };
    });

    const map = {};
    enriched.forEach(item => {
      map[item.nrp] = { ...item, children: [] };
    });
    
    let root = null;
    enriched.forEach(item => {
      if (item.atasan_nrp && map[item.atasan_nrp]) {
        map[item.atasan_nrp].children.push(map[item.nrp]);
      } else if (!item.atasan_nrp) {
        root = map[item.nrp];
      }
    });
    
    if (!root && enriched.length > 0) root = map[enriched[0].nrp];
    setTree(root);
  }, [orgData]);

  // Filter by business unit
  const filteredTree = React.useMemo(() => {
    if (!tree || businessUnit === 'ALL') return tree;
    const filterNode = (node) => {
      if (!node) return null;
      const filteredChildren = node.children
        .map(filterNode)
        .filter(Boolean);
      if (node.business_unit === businessUnit || filteredChildren.length > 0) {
        return { ...node, children: filteredChildren };
      }
      return null;
    };
    return filterNode(tree);
  }, [tree, businessUnit]);

  if (loading) return <PageLayout backTo="/admin" title="Struktur Organisasi"><LoadingSpinner text="Memuat struktur..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="Struktur Organisasi" subtitle={`${orgData.length} karyawan`}>
      {/* ── STATS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
        <StatItem label="Total" value={orgData.length} color="#38bdf8" />
        <StatItem label="Root" value={orgData.filter(d => !d.atasan_nrp).length || 1} color="#34d399" />
        <StatItem label="Divisi" value={new Set(orgData.map(d => d.divisi)).size} color="#a78bfa" />
        <StatItem label="Level Max" value={calcDepth(tree)} color="#fb923c" />
      </div>

      {/* ── FILTERS ── */}
      <div className="flex items-center gap-2 mb-4">
        <div className="flex-1">
          <Input placeholder="Cari NRP..." value={searchNrp} onChange={(e) => setSearchNrp(e.target.value)} icon="🔍" />
        </div>
        <select
          value={businessUnit}
          onChange={(e) => setBusinessUnit(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-800/50 border border-white/5 text-sm text-white"
        >
          <option value="ALL">Semua Unit</option>
          <option value="MINING">Tambang</option>
          <option value="ESTATE">Perkebunan</option>
          <option value="MILL">Pabrik</option>
          <option value="HQ">Korporat</option>
        </select>
      </div>

      {/* ── CHART ── */}
      <GlassCard accent="blue" className="overflow-x-auto">
        {filteredTree ? (
          <div className="min-w-[600px]">
            <OrgTreeNode
              node={filteredTree}
              level={0}
              searchNrp={searchNrp}
              onSelect={setSelectedNode}
              selectedNrp={selectedNode?.nrp}
            />
          </div>
        ) : (
          <EmptyState icon="🏢" title="Tidak ada data organisasi" />
        )}
      </GlassCard>

      {/* ── DETAIL PANEL ── */}
      {selectedNode && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm" onClick={() => setSelectedNode(null)}>
          <div className="fixed inset-x-0 bottom-0 z-50 max-h-[70vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-slate-600" /></div>
            <div className="px-5 pb-8">
              <div className="flex items-center gap-4 mb-4">
                <Avatar name={selectedNode.nama} size="lg" />
                <div>
                  <h3 className="text-lg font-bold text-white">{selectedNode.nama}</h3>
                  <p className="text-xs text-slate-400">{selectedNode.nrp} • {selectedNode.posisi || '-'}</p>
                  <div className="flex gap-2 mt-1">
                    <Badge status={selectedNode.divisi || '-'} type="info" />
                    <Badge status={selectedNode.business_unit || 'HQ'} type="success" />
                  </div>
                </div>
              </div>
              <div className="space-y-1">
                {[
                  { label: 'NRP', value: selectedNode.nrp },
                  { label: 'Divisi', value: selectedNode.divisi },
                  { label: 'Posisi', value: selectedNode.posisi },
                  { label: 'Atasan', value: selectedNode.atasan_nrp || 'Root (No Supervisor)' },
                  { label: 'Unit Bisnis', value: selectedNode.business_unit || 'HQ' },
                  { label: 'Bawahan Langsung', value: `${selectedNode.children?.length || 0} orang` },
                ].map((row, i) => (
                  <div key={i} className="flex justify-between py-2 border-b border-white/3">
                    <span className="text-xs text-slate-400">{row.label}</span>
                    <span className="text-xs font-semibold text-white">{row.value}</span>
                  </div>
                ))}
              </div>
              <button onClick={() => setSelectedNode(null)} className="mt-4 w-full py-2 rounded-xl bg-slate-800 text-sm text-slate-300">Tutup</button>
            </div>
          </div>
        </div>
      )}
    </PageLayout>
  );
}

// ── TREE NODE ──
function OrgTreeNode({ node, level, searchNrp, onSelect, selectedNrp }) {
  const [expanded, setExpanded] = useState(level < 2);
  if (!node) return null;
  const hasChildren = node.children?.length > 0;
  const isHighlighted = searchNrp && node.nrp?.toLowerCase().includes(searchNrp.toLowerCase());
  const isSelected = selectedNrp === node.nrp;

  const unitColors = {
    MINING: 'border-l-red-400 bg-red-500/5',
    ESTATE: 'border-l-green-400 bg-green-500/5',
    MILL: 'border-l-orange-400 bg-orange-500/5',
    HQ: 'border-l-blue-400 bg-blue-500/5',
  };

  return (
    <div className="mb-1">
      <div
        className={`flex items-center gap-2 py-2 px-3 rounded-xl border-l-4 cursor-pointer transition-all
          ${isSelected ? 'bg-teal-500/20 border-teal-500' : unitColors[node.business_unit] || 'border-l-slate-500 bg-white/3'}
          ${isHighlighted ? 'ring-2 ring-teal-400' : ''}
          hover:bg-white/5
        `}
        style={{ marginLeft: `${level * 20}px` }}
        onClick={() => onSelect(node)}
      >
        {hasChildren ? (
          <button onClick={(e) => { e.stopPropagation(); setExpanded(!expanded); }} className="text-xs text-slate-500 w-4">
            {expanded ? '▼' : '▶'}
          </button>
        ) : <span className="text-xs text-slate-700 w-4">•</span>}
        
        <Avatar name={node.nama} size="sm" />
        <div className="flex-1 min-w-0">
          <p className="text-xs font-bold text-white truncate">{node.nama}</p>
          <p className="text-[10px] text-slate-500">{node.nrp} • {node.posisi || '-'}</p>
        </div>
        {hasChildren && <Badge status={`${node.children.length}`} type="info" />}
      </div>
      
      {expanded && hasChildren && (
        <div className="ml-4 border-l border-white/10 pl-2">
          {node.children.map(child => (
            <OrgTreeNode key={child.nrp} node={child} level={level + 1} searchNrp={searchNrp} onSelect={onSelect} selectedNrp={selectedNrp} />
          ))}
        </div>
      )}
    </div>
  );
}

function calcDepth(node) {
  if (!node?.children?.length) return 0;
  return 1 + Math.max(...node.children.map(calcDepth));
}
