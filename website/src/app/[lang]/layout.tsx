import { RootProvider } from 'fumadocs-ui/provider/next';
import { i18nProvider } from 'fumadocs-ui/i18n';
import { i18n } from '@/lib/i18n';
import { ThemeInit } from '@/components/theme';

export default async function LangLayout({
  params,
  children,
}: {
  params: Promise<{ lang: string }>;
  children: React.ReactNode;
}) {
  const { lang } = await params;

  const translations = i18n.translations().add({
    en: { displayName: 'English' },
    ru: { displayName: 'Русский' },
  });

  return (
    <RootProvider
      i18n={i18nProvider(translations, lang)}
      theme={{ enabled: false }}
    >
      <ThemeInit />
      {children}
    </RootProvider>
  );
}
