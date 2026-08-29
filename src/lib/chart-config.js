'use client';

import { useEffect, useRef } from 'react';

// Dynamic import Chart.js
let chartLib = null;

async function getChartJS() {
  if (chartLib) return chartLib;
  const Chart = await import('chart.js/auto');
  chartLib = Chart.default || Chart;
  return chartLib;
}

// Colors matching our theme
export const COLORS = {
  primary: '#38bdf8',
  secondary: '#818cf8',
  success: '#34d399',
  warning: '#fbbf24',
  error: '#f87171',
  muted: '#64748b',
  grid: 'rgba(148,163,184,0.1)',
  text: '#94a3b8',
  bg: '#1e293b',
};

export const CHART_DEFAULTS = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1e293b',
      titleColor: '#e2e8f0',
      bodyColor: '#94a3b8',
      borderColor: '#334155',
      borderWidth: 1,
      cornerRadius: 8,
      padding: 10,
    },
  },
  scales: {
    x: {
      grid: { color: COLORS.grid },
      ticks: { color: COLORS.text, font: { size: 10 } },
    },
    y: {
      grid: { color: COLORS.grid },
      ticks: { color: COLORS.text, font: { size: 10 } },
    },
  },
};

// Reusable chart hook
export function useChart(configFn, deps = []) {
  const canvasRef = useRef(null);
  const chartRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    async function render() {
      if (!canvasRef.current) return;
      const Chart = await getChartJS();
      if (cancelled) return;

      if (chartRef.current) {
        chartRef.current.destroy();
      }

      const cfg = configFn(Chart);
      chartRef.current = new Chart(canvasRef.current, cfg);
    }
    render();
    return () => {
      cancelled = true;
      if (chartRef.current) {
        chartRef.current.destroy();
        chartRef.current = null;
      }
    };
  }, deps);

  return canvasRef;
}

// ---- Common chart builders ----

export function buildBarChart(labels, data, color = COLORS.primary) {
  return (Chart) => ({
    type: 'bar',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: color + '99',
        borderColor: color,
        borderWidth: 1,
        borderRadius: 4,
        barPercentage: 0.6,
      }],
    },
    options: {
      ...CHART_DEFAULTS,
      plugins: { ...CHART_DEFAULTS.plugins, legend: { display: false } },
    },
  });
}

export function buildLineChart(labels, datasets) {
  return (Chart) => ({
    type: 'line',
    data: {
      labels,
      datasets: datasets.map((ds, i) => ({
        label: ds.label,
        data: ds.data,
        borderColor: [COLORS.primary, COLORS.success, COLORS.warning, COLORS.error, COLORS.secondary][i % 5],
        backgroundColor: 'transparent',
        borderWidth: 2,
        tension: 0.3,
        pointRadius: 3,
        pointBackgroundColor: [COLORS.primary, COLORS.success, COLORS.warning, COLORS.error, COLORS.secondary][i % 5],
      })),
    },
    options: {
      ...CHART_DEFAULTS,
      plugins: {
        ...CHART_DEFAULTS.plugins,
        legend: datasets.length > 1 ? {
          display: true,
          labels: { color: COLORS.text, font: { size: 10 }, boxWidth: 12 },
        } : { display: false },
      },
    },
  });
}

export function buildDoughnutChart(labels, data, colors) {
  return (Chart) => ({
    type: 'doughnut',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: colors || [COLORS.success, COLORS.warning, COLORS.error, COLORS.primary, COLORS.secondary, COLORS.muted],
        borderColor: '#1e293b',
        borderWidth: 2,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: true, position: 'bottom', labels: { color: COLORS.text, font: { size: 10 }, boxWidth: 12, padding: 8 } },
        tooltip: CHART_DEFAULTS.plugins.tooltip,
      },
    },
  });
}
