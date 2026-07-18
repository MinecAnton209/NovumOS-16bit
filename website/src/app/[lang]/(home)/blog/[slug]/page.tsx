import { notFound } from 'next/navigation';
import Link from 'next/link';
import { InlineTOC } from 'fumadocs-ui/components/inline-toc';
import defaultMdxComponents from 'fumadocs-ui/mdx';
import { blog } from '@/lib/source';
import type { Metadata } from 'next';

export default async function Page({
  params,
}: {
  params: Promise<{ lang: string; slug: string }>;
}) {
  const { lang, slug } = await params;
  const page = blog.getPage([slug]);

  if (!page) notFound();
  const Mdx = page.data.body;

  return (
    <>
      <div className="w-full max-w-[1400px] mx-auto px-4 py-12 rounded-xl border md:px-8">
        <h1 className="mb-2 text-3xl font-bold">{page.data.title}</h1>
        {page.data.description && (
          <p className="mb-4 text-fd-muted-foreground">{page.data.description}</p>
        )}
        <Link href={`/${lang}/blog`} className="text-sm text-fd-muted-foreground hover:text-fd-accent-foreground">
          ← Back to blog
        </Link>
      </div>
      <article className="w-full max-w-[1400px] mx-auto flex flex-col px-4 py-8 md:flex-row gap-8">
        <div className="prose min-w-0 flex-1">
          <InlineTOC items={page.data.toc} />
          <Mdx components={defaultMdxComponents} />
        </div>
        <aside className="md:w-48 flex flex-col gap-4 text-sm">
          {page.data.author && (
            <div>
              <p className="mb-1 text-fd-muted-foreground">Written by</p>
              <p className="font-medium">{page.data.author}</p>
            </div>
          )}
          {page.data.date && (
            <div>
              <p className="mb-1 text-sm text-fd-muted-foreground">Published</p>
              <p className="font-medium">
                {new Date(page.data.date).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric',
                })}
              </p>
            </div>
          )}
        </aside>
      </article>
    </>
  );
}

export function generateStaticParams(): { lang: string; slug: string }[] {
  const languages = ['en', 'ru'];
  return blog.getPages().flatMap((page) =>
    languages.map((lang) => ({
      lang,
      slug: page.slugs[0],
    })),
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ lang: string; slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const page = blog.getPage([slug]);
  if (!page) notFound();

  return {
    title: page.data.title,
    description: page.data.description,
  };
}
