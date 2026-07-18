import Link from 'next/link';
import { blog } from '@/lib/source';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Blog',
  description: 'Dev logs and updates about NovumOS-16bit',
};

export default function BlogPage() {
  const posts = blog.getPages();

  return (
    <main className="flex-1 w-full max-w-[1400px] mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-2">Blog</h1>
      <p className="text-fd-muted-foreground mb-8">
        Dev logs, updates, and deep dives into the NovumOS-16bit project.
      </p>
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {posts.map((post) => (
          <Link
            key={post.url}
            href={post.url}
            className="block bg-fd-secondary rounded-lg shadow-md overflow-hidden p-6 hover:bg-fd-accent transition-colors"
          >
            <h2 className="text-xl font-semibold mb-2">{post.data.title}</h2>
            {post.data.description && (
              <p className="text-fd-muted-foreground mb-4">{post.data.description}</p>
            )}
            <div className="flex gap-4 text-sm text-fd-muted-foreground">
              {post.data.date && (
                <time dateTime={new Date(post.data.date).toISOString()}>
                  {new Date(post.data.date).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </time>
              )}
            </div>
          </Link>
        ))}
      </div>
    </main>
  );
}
