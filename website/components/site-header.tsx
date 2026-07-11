import Link from "next/link";

export function SiteHeader() {
  return (
    <header className="site-header">
      <Link className="brand" href="/">Tracal</Link>
      <nav className="site-nav" aria-label="Primary navigation">
        <Link href="/#privacy">Privacy</Link>
        <Link href="/#pricing">Pricing</Link>
        <Link href="/support">Support</Link>
      </nav>
    </header>
  );
}
