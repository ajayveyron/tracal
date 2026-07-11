import type { ReactNode } from "react";

type LegalPageProps = {
  title: string;
  summary: string;
  children: ReactNode;
};

export function LegalPage({ title, summary, children }: LegalPageProps) {
  return (
    <main>
      <header className="page-hero">
        <h1>{title}</h1>
        <p>{summary}</p>
      </header>
      <div className="legal-grid">
        <aside className="legal-meta">
          <p>Effective</p>
          <strong>11 July 2026</strong>
        </aside>
        <article className="legal-content">{children}</article>
      </div>
    </main>
  );
}
