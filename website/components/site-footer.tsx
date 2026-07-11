import Link from "next/link";

const links = [
  ["Privacy", "/privacy"],
  ["Terms", "/terms"],
  ["Support", "/support"],
  ["API key safety", "/api-key-safety"],
  ["Provider billing", "/provider-billing"],
  ["Refunds", "/refunds"],
] as const;

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div>
          <Link className="brand" href="/">Tracal</Link>
          <p>Private calorie tracking for iPhone. Nutrition estimates are not medical advice.</p>
        </div>
        <nav className="footer-links" aria-label="Legal and support">
          {links.map(([label, href]) => <Link key={href} href={href}>{label}</Link>)}
        </nav>
      </div>
    </footer>
  );
}
