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

  return (
    <div className="flex-1">
      {/* ── Hero Section ── */}
      <section className="relative overflow-hidden border-b border-fd-border">
        {/* Decorative grid pattern */}
        <div className="absolute inset-0 bg-[linear-gradient(rgba(128,128,128,0.05)_1px,transparent_1px),linear-gradient(90deg,rgba(128,128,128,0.05)_1px,transparent_1px)] bg-[size:64px_64px] [mask-image:radial-gradient(ellipse_80%_50%_at_50%_0%,black_30%,transparent_70%)]" />

        <div className="relative mx-auto max-w-5xl px-6 py-24 sm:py-32 lg:py-40">
          <div className="text-center">
            <h1 className="text-4xl font-bold tracking-tight sm:text-6xl lg:text-7xl">
              <span className="bg-gradient-to-r from-fd-foreground via-fd-foreground to-fd-muted-foreground bg-clip-text text-transparent">
                {appName}
              </span>
            </h1>

            <p className="mt-6 max-w-2xl mx-auto text-lg leading-relaxed text-fd-muted-foreground sm:text-xl">
              {appDescription}
            </p>

            <p className="mt-3 text-base text-fd-muted-foreground/70">
              Designed for a custom CPU built from discrete TTL NAND gates.
            </p>

            {/* CTA Buttons */}
            <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
              <Link
                href={`/${lang}/docs`}
                className="inline-flex items-center gap-2 rounded-lg bg-fd-primary px-6 py-3 text-sm font-semibold text-fd-primary-foreground shadow-sm transition-all hover:brightness-110"
              >
                Read the Docs
                <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </Link>
              <Link
                href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
                className="inline-flex items-center gap-2 rounded-lg border border-fd-border bg-fd-secondary/50 px-6 py-3 text-sm font-semibold text-fd-foreground transition-all hover:bg-fd-accent"
              >
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                </svg>
                GitHub
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ── Features Grid ── */}
      <section className="mx-auto max-w-5xl px-6 py-20">
        <div className="grid gap-6 sm:grid-cols-2">
          {features.map((feature) => {
            const Icon = feature.icon;
            return (
              <div
                key={feature.title}
                className="group relative rounded-xl border border-fd-border bg-fd-card p-6 transition-all hover:border-fd-muted-foreground/30 hover:shadow-sm"
              >
                <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-fd-secondary">
                  <Icon className="h-5 w-5 text-fd-foreground" />
                </div>
                <h3 className="mb-2 text-lg font-semibold text-fd-foreground">
                  {feature.title}
                </h3>
                <p className="text-sm leading-relaxed text-fd-muted-foreground">
                  {feature.description}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      {/* ── Stats Section ── */}
      <section className="border-y border-fd-border bg-fd-secondary/30">
        <div className="mx-auto max-w-5xl px-6 py-16">
          <div className="grid gap-8 sm:grid-cols-3">
            {stats.map((stat) => (
              <div key={stat.label} className="text-center">
                <div className="text-3xl font-bold text-fd-foreground">{stat.value}</div>
                <div className="mt-1 text-sm text-fd-muted-foreground">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Blog Preview ── */}
      {posts.length > 0 && (
        <section className="mx-auto max-w-5xl px-6 py-20">
          <div className="mb-10 flex items-end justify-between">
            <div>
              <h2 className="text-2xl font-bold text-fd-foreground">Latest Posts</h2>
              <p className="mt-1 text-sm text-fd-muted-foreground">
                Dev logs and updates
              </p>
            </div>
            <Link
              href={`/${lang}/blog`}
              className="text-sm font-medium text-fd-muted-foreground hover:text-fd-foreground transition-colors"
            >
              View all →
            </Link>
          </div>
          <div className="grid gap-6 sm:grid-cols-3">
            {posts.map((post) => (
              <Link
                key={post.url}
                href={post.url}
                className="group rounded-xl border border-fd-border bg-fd-card p-5 transition-all hover:border-fd-muted-foreground/30 hover:shadow-sm"
              >
                <h3 className="font-semibold text-fd-foreground group-hover:text-fd-accent-foreground transition-colors">
                  {post.data.title}
                </h3>
                {post.data.description && (
                  <p className="mt-2 text-sm text-fd-muted-foreground line-clamp-2">
                    {post.data.description}
                  </p>
                )}
                {post.data.date && (
                  <time
                    dateTime={new Date(post.data.date).toISOString()}
                    className="mt-3 block text-xs text-fd-muted-foreground"
                  >
                    {new Date(post.data.date).toLocaleDateString(lang === 'ru' ? 'ru-RU' : 'en-US', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    })}
                  </time>
                )}
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* ── Footer ── */}
      <footer className="border-t border-fd-border">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-4 px-6 py-8 text-center sm:flex-row sm:text-left">
          <p className="text-sm text-fd-muted-foreground">
            Built with Zig · Powered by TTL
          </p>
          <p className="text-sm text-fd-muted-foreground">
            <Link
              href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
              className="hover:text-fd-foreground transition-colors"
            >
              {gitConfig.user}/{gitConfig.repo}
            </Link>
          </p>
        </div>
      </footer>
    </div>
  );
}

// ── Feature Data ──

interface Feature {
  title: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
}

const features: Feature[] = [
  {
    title: 'Custom 16-bit ISA',
    description:
      '12 instructions tailored for TTL logic: MOV, ALU, JMP, CALL/RET, INT/IRET, HLT, IN/OUT, conditional jumps, and stack operations.',
    icon: CpuIcon,
  },
  {
    title: 'Cycle-Accurate Emulator',
    description:
      'Full CPU emulator in Zig with 64 KB addressable memory, 4 registers, VGA text output, UART serial, and a programmable timer.',
    icon: TerminalIcon,
  },
  {
    title: 'Zig-Powered Toolchain',
    description:
      'Comptime code generation, instruction encoding, and firmware assembly — all in pure Zig. No external assembler required.',
    icon: CodeIcon,
  },
  {
    title: 'TTL NAND Hardware',
    description:
      'Designed to run on a discrete 16-bit CPU built from 74xx-series TTL NAND gates. Every instruction maps directly to the hardware decoder.',
    icon: ChipIcon,
  },
];

const stats = [
  { value: '16-bit', label: 'Architecture' },
  { value: '~400', label: 'TTL Chips' },
  { value: '64 KB', label: 'Addressable RAM' },
];

// ── Inline SVG Components ──

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
