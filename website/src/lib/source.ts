import { enDocs, ruDocs, blogPosts } from 'collections/server';
import { toFumadocsSource } from 'fumadocs-mdx/runtime/server';
import { loader } from 'fumadocs-core/source';
import { docsRoute, docsImageRoute, docsContentRoute } from './shared';

// English docs
export const enSource = loader({
  baseUrl: docsRoute,
  source: enDocs.toFumadocsSource(),
});

// Russian docs
export const ruSource = loader({
  baseUrl: docsRoute,
  source: ruDocs.toFumadocsSource(),
});

// Blog
export const blog = loader({
  baseUrl: '/blog',
  source: toFumadocsSource(blogPosts, []),
});

/** Get the appropriate docs source for a given language */
export function getSource(lang: string) {
  return lang === 'ru' ? ruSource : enSource;
}

export function getPageImage(page: (typeof enSource)['$inferPage']) {
  const segments = [...page.slugs, 'image.png'];
  return {
    segments,
    url: `${docsImageRoute}/${segments.join('/')}`,
  };
}

export function getPageMarkdownUrl(page: (typeof enSource)['$inferPage']) {
  const segments = [...page.slugs, 'content.md'];
  return {
    segments,
    url: `${docsContentRoute}/${segments.join('/')}`,
  };
}

export type Page = (typeof enSource)['$inferPage'];
