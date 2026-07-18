'use client';

import Script from 'next/script';

/**
 * Initializes the theme before React hydration using next/script
 * with beforeInteractive strategy (avoids React 19 <script> warning).
 */
const themeScript = `
(function() {
  try {
    var theme = localStorage.getItem('theme') || 'system';
    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    var resolved = theme === 'system' ? (prefersDark ? 'dark' : 'light') : theme;
    document.documentElement.classList.add(resolved);
    document.documentElement.style.colorScheme = resolved;
  } catch(e) {}
})();
`;

export function ThemeInit() {
  return (
    <Script
      id="theme-init"
      strategy="beforeInteractive"
      dangerouslySetInnerHTML={{ __html: themeScript }}
    />
  );
}
