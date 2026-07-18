import Link from 'next/link';
import { blog } from '@/lib/source';
import { appName, appDescription, gitConfig } from '@/lib/shared';

export default async function HomePage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  const posts = blog.getPages().slice(0, 3);

  const t = lang === 'ru' ? ru : en;

  return (
    <div className="flex-1">
      {/* ── Hero ── */}
      <section className="relative overflow-hidden border-b border-fd-border">
        <div className="absolute inset-0 bg-[linear-gradient(rgba(128,128,128,0.04)_1px,transparent_1px),linear-gradient(90deg,rgba(128,128,128,0.04)_1px,transparent_1px)] bg-[size:64px_64px]" />
        <div className="relative mx-auto max-w-5xl px-6 py-24 sm:py-32 text-center">
          <h1 className="text-5xl font-bold tracking-tight sm:text-7xl">{appName}</h1>
          <p className="mt-6 max-w-2xl mx-auto text-lg text-fd-muted-foreground sm:text-xl">
            {appDescription}
          </p>
          <p className="mt-2 text-sm text-fd-muted-foreground/60">
            {t.subtitle}
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
            <Link
              href={`/${lang}/docs`}
              className="inline-flex items-center gap-2 rounded-lg bg-fd-primary px-5 py-2.5 text-sm font-semibold text-fd-primary-foreground shadow-xs hover:brightness-110 transition-all"
            >
              {t.readDocs}
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </Link>
            <Link
              href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
              className="inline-flex items-center gap-2 rounded-lg border border-fd-border px-5 py-2.5 text-sm font-semibold text-fd-foreground hover:bg-fd-accent transition-all"
            >
              <GithubIcon className="h-5 w-5" />
              GitHub
            </Link>
          </div>
        </div>
      </section>

      {/* ── How it works: 3 steps ── */}
      <section className="mx-auto max-w-5xl px-6 py-20">
        <h2 className="text-center text-2xl font-bold sm:text-3xl">{t.howItWorks}</h2>
        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          <StepCard number="1" title={t.step1Title} desc={t.step1Desc} />
          <StepCard number="2" title={t.step2Title} desc={t.step2Desc} />
          <StepCard number="3" title={t.step3Title} desc={t.step3Desc} />
        </div>
      </section>

      {/* ── Instruction set preview ── */}
      <section className="border-y border-fd-border bg-fd-secondary/20">
        <div className="mx-auto max-w-5xl px-6 py-20">
          <div className="text-center mb-10">
            <span className="text-xs font-semibold tracking-widest uppercase text-fd-muted-foreground/60">ISA</span>
            <h2 className="mt-2 text-2xl font-bold sm:text-3xl">{t.isaTitle}</h2>
          </div>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
            {(lang === 'ru' ? instructionsRu : instructionsEn).map((inst) => (
              <div key={inst[0]} className="rounded-lg border border-fd-border bg-fd-card p-3 text-center">
                <code className="text-sm font-bold font-mono">{inst[0]}</code>
                <p className="mt-0.5 text-xs text-fd-muted-foreground">{inst[1]}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Features ── */}
      <section className="mx-auto max-w-5xl px-6 py-20">
        <h2 className="text-center text-2xl font-bold sm:text-3xl">{t.featuresTitle}</h2>
        <div className="mt-10 grid gap-5 sm:grid-cols-2">
          {[
            { title: t.feature1Title, desc: t.feature1Desc, icon: CpuIcon },
            { title: t.feature2Title, desc: t.feature2Desc, icon: TerminalIcon },
            { title: t.feature3Title, desc: t.feature3Desc, icon: CodeIcon },
            { title: t.feature4Title, desc: t.feature4Desc, icon: ChipIcon },
          ].map((f) => {
            const Icon = f.icon;
            return (
              <div key={f.title} className="rounded-xl border border-fd-border bg-fd-card p-5 transition-all hover:shadow-sm">
                <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-lg bg-fd-secondary">
                  <Icon className="h-5 w-5" />
                </div>
                <h3 className="font-semibold">{f.title}</h3>
                <p className="mt-1 text-sm text-fd-muted-foreground">{f.desc}</p>
              </div>
            );
          })}
        </div>
      </section>

      {/* ── Blog ── */}
      {posts.length > 0 && (
        <section className="border-t border-fd-border bg-fd-secondary/20">
          <div className="mx-auto max-w-5xl px-6 py-20">
            <div className="flex items-end justify-between mb-8">
              <h2 className="text-2xl font-bold">{t.latestPosts}</h2>
              <Link href={`/${lang}/blog`} className="text-sm text-fd-muted-foreground hover:text-fd-foreground transition-colors">
                {t.viewAll} →
              </Link>
            </div>
            <div className="grid gap-5 sm:grid-cols-3">
              {posts.map((post) => (
                <Link
                  key={post.url}
                  href={post.url}
                  className="rounded-xl border border-fd-border bg-fd-card p-5 transition-all hover:shadow-sm"
                >
                  <h3 className="font-semibold">{post.data.title}</h3>
                  {post.data.description && (
                    <p className="mt-1 text-sm text-fd-muted-foreground line-clamp-2">{post.data.description}</p>
                  )}
                  {post.data.date && (
                    <time dateTime={new Date(post.data.date).toISOString()} className="mt-3 block text-xs text-fd-muted-foreground">
                      {new Date(post.data.date).toLocaleDateString(lang === 'ru' ? 'ru-RU' : 'en-US', {
                        year: 'numeric', month: 'long', day: 'numeric',
                      })}
                    </time>
                  )}
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Stats bar ── */}
      <section className="mx-auto max-w-5xl px-6 py-16">
        <div className="grid gap-6 sm:grid-cols-3">
          {stats.map((s) => (
            <div key={s.label} className="text-center">
              <div className="text-2xl font-bold">{s.value}</div>
              <div className="mt-0.5 text-sm text-fd-muted-foreground">{s.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="border-t border-fd-border">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-3 px-6 py-8 text-center sm:flex-row">
          <p className="text-sm text-fd-muted-foreground">{t.footer}</p>
          <Link
            href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
            className="text-sm text-fd-muted-foreground hover:text-fd-foreground transition-colors"
          >
            {gitConfig.user}/{gitConfig.repo}
          </Link>
        </div>
      </footer>
    </div>
  );
}

// ── Helpers ──

function StepCard({ number, title, desc }: { number: string; title: string; desc: string }) {
  return (
    <div className="text-center">
      <div className="mx-auto mb-4 flex h-10 w-10 items-center justify-center rounded-full bg-fd-secondary text-sm font-bold">{number}</div>
      <h3 className="font-semibold">{title}</h3>
      <p className="mt-1.5 text-sm text-fd-muted-foreground">{desc}</p>
    </div>
  );
}

function GithubIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
  );
}

// ── Data ──

const en = {
  subtitle: 'Designed for a custom CPU built from discrete TTL NAND gates',
  readDocs: 'Read the Docs',
  howItWorks: 'How It Works',
  step1Title: 'Write in Zig',
  step1Desc: 'Firmware is written in Zig and assembled at compile time — no external toolchain needed.',
  step2Title: 'Run in Emulator',
  step2Desc: 'The built-in emulator loads the firmware and executes it cycle-accurately.',
  step3Title: 'Deploy to Hardware',
  step3Desc: 'The same binary runs on the real TTL CPU with no modifications.',
  isaTitle: '12 Instructions',
  featuresTitle: 'Features',
  feature1Title: 'Custom 16-bit ISA',
  feature1Desc: '12 instructions tailored for TTL logic: MOV, ALU, JMP, CALL/RET, INT/IRET, HLT, IN/OUT, conditional jumps, and stack operations.',
  feature2Title: 'Cycle-Accurate Emulator',
  feature2Desc: 'Full CPU emulator in Zig with 64 KB addressable memory, 4 registers, VGA text output, UART serial, and a programmable timer.',
  feature3Title: 'Zig-Powered Toolchain',
  feature3Desc: 'Comptime code generation, instruction encoding, and firmware assembly — all in pure Zig. No external assembler required.',
  feature4Title: 'Real TTL Hardware',
  feature4Desc: 'Designed for a discrete 16-bit CPU built from ~400 74xx-series TTL NAND gates. Every instruction maps to the hardware decoder.',
  latestPosts: 'Latest Posts',
  viewAll: 'View all',
  footer: 'Built with Zig · Powered by TTL',
};

const ru = {
  subtitle: 'Спроектирована для процессора из дискретных TTL NAND-вентилей',
  readDocs: 'Читать документацию',
  howItWorks: 'Как это работает',
  step1Title: 'Пиши на Zig',
  step1Desc: 'Прошивка пишется на Zig и собирается на этапе компиляции — никаких внешних инструментов.',
  step2Title: 'Запусти в эмуляторе',
  step2Desc: 'Встроенный эмулятор загружает прошивку и исполняет её такт-в-такт.',
  step3Title: 'Загрузи на железо',
  step3Desc: 'Тот же бинарник работает на реальном TTL-процессоре без изменений.',
  isaTitle: '12 инструкций',
  featuresTitle: 'Возможности',
  feature1Title: 'Своя 16-битная ISA',
  feature1Desc: '12 инструкций, заточенных под TTL-логику: MOV, ALU, JMP, CALL/RET, INT/IRET, HLT, IN/OUT, условные переходы и стек.',
  feature2Title: 'Точный эмулятор',
  feature2Desc: 'Полноценный эмулятор CPU на Zig с 64 КБ памяти, 4 регистрами, VGA-выводом, UART и программируемым таймером.',
  feature3Title: 'Инструментарий на Zig',
  feature3Desc: 'Генерация кода на этапе компиляции, кодирование инструкций и сборка прошивки — всё на чистом Zig, без внешнего ассемблера.',
  feature4Title: 'Настоящее TTL-железо',
  feature4Desc: 'Спроектирована для 16-битного процессора из ~400 микросхем 74xx-серии TTL NAND. Каждая инструкция соответствует аппаратному декодеру.',
  latestPosts: 'Последние посты',
  viewAll: 'Все',
  footer: 'Собрано на Zig · Работает на TTL',
};

const instructionsEn: [string, string][] = [
  ['MOV', 'Load / store'],
  ['ALU', 'ADD, SUB, AND, OR…'],
  ['JMP', 'Unconditional jump'],
  ['CALL/RET', 'Subroutine calls'],
  ['CondJump', 'JZ/JC/JS/etc.'],
  ['PUSH/POP', 'Stack operations'],
  ['INT/IRET', 'Interrupts'],
  ['IN', 'I/O port read'],
  ['OUT', 'I/O port write'],
  ['HLT', 'Halt CPU'],
];

const instructionsRu: [string, string][] = [
  ['MOV', 'Загрузка / сохранение'],
  ['ALU', 'ADD, SUB, AND, OR…'],
  ['JMP', 'Безусловный переход'],
  ['CALL/RET', 'Вызов подпрограммы'],
  ['CondJump', 'JZ/JC/JS и др.'],
  ['PUSH/POP', 'Работа со стеком'],
  ['INT/IRET', 'Прерывания'],
  ['IN', 'Чтение порта ввода'],
  ['OUT', 'Запись в порт вывода'],
  ['HLT', 'Остановка CPU'],
];

const stats = [
  { value: '16-bit', label: 'Architecture' },
  { value: '~400', label: 'TTL Chips' },
  { value: '64 KB', label: 'Addressable RAM' },
];

function CpuIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
    </svg>
  );
}
function CodeIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
    </svg>
  );
}
function TerminalIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
  );
}
function ChipIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
    </svg>
  );
}
