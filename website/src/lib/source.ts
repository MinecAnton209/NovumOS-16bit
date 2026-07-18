import { enDocs, ruDocs, blogPosts } from 'collections/server';
import { toFumadocsSource } from 'fumadocs-mdx/runtime/server';
import { multiple, loader } from 'fumadocs-core/source';
import { i18n } from './i18n';
import { docsRoute } from './shared';

// Combined i18n source — single loader handles both en and ru
export const source = loader({
  baseUrl: docsRoute,
  i18n,
  source: multiple({
    en: enDocs.toFumadocsSource(),
    ru: ruDocs.toFumadocsSource(),
  }),
});

// Blog (shared between languages)
export const blog = loader({
  baseUrl: '/blog',
  source: toFumadocsSource(blogPosts, []),
});

/** Get a specific language's page tree (for sidebar) */
export function getPageTree(lang: string) {
  return source.getPageTree(lang);
}

export function getPageImage(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'image.png'];
  return {
    segments,
    url: `/og/docs/${segments.join('/')}`,
  };
}

export function getPageMarkdownUrl(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'content.md'];
  return {
    segments,
    url: `/llms.mdx/docs/${segments.join('/')}`,
  };
}

/** Get the markdown content of a page as text (for llms) */
export function getLLMText(page: (typeof source)['$inferPage']): Promise<string> {
  // In a full implementation, this would render the page's MDX to plain text
  // For now, return the page description as a placeholder
  return Promise.resolve(page.data.description ?? page.data.title ?? '');
}

export type Page = (typeof source)['$inferPage'];
