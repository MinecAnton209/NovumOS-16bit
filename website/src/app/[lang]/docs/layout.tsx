import { getSource } from '@/lib/source';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { baseOptions } from '@/lib/layout.shared';

export default async function Layout({
  params,
  children,
}: {
  params: Promise<{ lang: string }>;
  children: React.ReactNode;
}) {
  const { lang } = await params;
  const source = getSource(lang);

  return (
    <DocsLayout tree={source.getPageTree()} {...baseOptions(lang)}>
      {children}
    </DocsLayout>
  );
}
