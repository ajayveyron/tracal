import Link from "next/link";

export default function Home() {
  return (
    <main>
      <section className="hero">
        <h1>Log the meal. Keep the data.</h1>
        <p>Tracal is a private calorie tracker for iPhone. Type what you ate, take a photo, or choose one from your library. Your meal history stays on your device.</p>
        <div className="actions">
          <Link className="button" href="/privacy">See how privacy works</Link>
          <Link className="button secondary" href="/support">Get support</Link>
        </div>
      </section>

      <section className="feature-grid" aria-label="Features">
        <article className="feature-card">
          <h2>Local by default</h2>
          <p>Meals, goals, photos, and usage history live on this iPhone. There is no Tracal account, cloud meal database, advertising, or third-party analytics.</p>
        </article>
        <article className="feature-card">
          <h2>Three quick ways to log</h2>
          <p>Open Text, Camera, or Gallery from the app or Home Screen widget. Nutrition-label OCR and deterministic parsing run on-device first.</p>
        </article>
        <article className="feature-card">
          <h2>Your provider, your key</h2>
          <p>Optional cloud estimates go directly to OpenAI, Anthropic, or Gemini after you select a provider, paste an API key, and consent.</p>
        </article>
        <article className="feature-card" id="privacy">
          <h2>Clear before anything leaves</h2>
          <p>Tracal tells you before meal text or a sanitized image is sent. It never silently falls back to a different cloud provider.</p>
        </article>
        <article className="feature-card">
          <h2>Costs you can inspect</h2>
          <p>See reported tokens and estimated API cost by month, provider, and model. Provider dashboards remain the billing source of truth.</p>
        </article>
        <article className="feature-card">
          <h2>Portable, not trapped</h2>
          <p>Export a local backup, import it later, reset usage history, or delete everything. API keys are never included in backups.</p>
        </article>
      </section>

      <section className="price-panel" id="pricing">
        <div className="price-copy">
          <h2>Pay once for Tracal.</h2>
          <p>The App Store purchase covers the app. Optional provider API access and usage are separate and billed by the provider.</p>
        </div>
        <div className="price">$8.99<small>Launch price for the first 100 recorded buyers. Standard price: $19.99. Apple localizes prices by storefront.</small></div>
      </section>

      <section className="plain-section">
        <h2>Useful estimates, with the right limits.</h2>
        <p>Nutrition values can be incomplete or wrong. Review entries before relying on them. Tracal is not a medical device and does not diagnose, treat, cure, or prevent any condition.</p>
      </section>
    </main>
  );
}
