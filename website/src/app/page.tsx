import { redirect } from 'next/navigation';
import { headers } from 'next/headers';

export const dynamic = 'force-dynamic';

export default async function RootPage() {
  const hdrs = await headers();
  const acceptLang = hdrs.get('accept-language') ?? '';
  const lang = acceptLang.startsWith('ru') ? 'ru' : 'en';
  redirect(`/${lang}`);
}
