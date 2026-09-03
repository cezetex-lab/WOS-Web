// ============================================================
// SkipToContent.jsx - WCAG: Skip to main content link
// ============================================================
export default function SkipToContent() {
  return (
    <a
      href="#main-content"
      className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[9999] focus:bg-blue-600 focus:text-white focus:px-4 focus:py-2 focus:rounded-lg focus:shadow-lg focus:outline-none"
      tabIndex={0}
    >
      Lewati ke konten utama
    </a>
  );
}
