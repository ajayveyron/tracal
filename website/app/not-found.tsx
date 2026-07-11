import Link from "next/link";

export default function NotFound() {
  return (
    <main className="page-hero">
      <h1>Page not found.</h1>
      <p>The page may have moved. <Link href="/">Return to Tracal</Link>.</p>
    </main>
  );
}
