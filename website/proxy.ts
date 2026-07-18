import { NextRequest, NextResponse } from 'next/server';
import { createI18nMiddleware } from 'fumadocs-core/i18n/middleware';
import { isMarkdownPreferred, rewritePath } from 'fumadocs-core/negotiation';
import { i18n } from '@/lib/i18n';
import { docsContentRoute, docsRoute } from '@/lib/shared';

const i18nHandler = createI18nMiddleware(i18n) as unknown as (req: NextRequest) => ReturnType<typeof NextResponse.next>;

const { rewrite: rewriteDocs } = rewritePath(
  `${docsRoute}{/*path}`,
  `${docsContentRoute}{/*path}/content.md`,
);
const { rewrite: rewriteSuffix } = rewritePath(
  `${docsRoute}{/*path}.md`,
  `${docsContentRoute}{/*path}/content.md`,
);

export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip API, static, and asset routes
  if (pathname.match(/^\/(api|_next\/static|_next\/image|favicon\.ico|og)/)) {
    return NextResponse.next();
  }

  // i18n — redirect to language prefix if missing
  const i18nResult = i18nHandler(request);
  if (i18nResult) return i18nResult;

  // Content markdown rewrites
  const result = rewriteSuffix(pathname);
  if (result) {
    return NextResponse.rewrite(new URL(result, request.nextUrl));
  }

  if (isMarkdownPreferred(request)) {
    const result = rewriteDocs(pathname);
    if (result) {
      return NextResponse.rewrite(new URL(result, request.nextUrl));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/:path*'],
};
