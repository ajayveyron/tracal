import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Provider billing" };

export default function ProviderBillingPage() {
  return (
    <LegalPage title="Provider billing" summary="The App Store purchase pays for Tracal. Optional OpenAI, Anthropic, or Gemini API usage is a separate relationship between you and that provider.">
      <h2>Subscriptions are not API access</h2>
      <p>A ChatGPT, Claude, or Gemini consumer subscription generally does not fund developer API requests. Use a valid API key from the provider’s developer platform and follow its billing requirements.</p>

      <h2>What providers may charge</h2>
      <p>Charges depend on the provider, model, input and output tokens, image processing, caching, service tier, free allowance, tax, and account agreement. Tracal does not set, collect, or refund provider charges.</p>

      <h2>Estimated API cost</h2>
      <p>When a provider returns usage details, Tracal stores token counts and estimates cost using a dated local price catalog. Missing usage is shown as unknown, not zero. Retries are separate attempts. Provider dashboards remain the source of truth because prices, free tiers, discounts, and billing rules can change.</p>

      <h2>Protect against surprises</h2>
      <ul>
        <li>Use a dedicated key and project.</li>
        <li>Set provider spending caps and alerts.</li>
        <li>Check the provider dashboard regularly.</li>
        <li>Delete or revoke a key you no longer use.</li>
      </ul>

      <h2>Provider resources</h2>
      <ul>
        <li><a href="https://openai.com/api/pricing/">OpenAI API pricing</a></li>
        <li><a href="https://docs.anthropic.com/en/docs/about-claude/pricing">Anthropic API pricing</a></li>
        <li><a href="https://ai.google.dev/gemini-api/docs/pricing">Gemini API pricing</a></li>
      </ul>
    </LegalPage>
  );
}
