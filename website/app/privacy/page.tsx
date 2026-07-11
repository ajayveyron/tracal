import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Privacy policy" };

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy policy" summary="Tracal keeps your records on your iPhone. Optional cloud analysis is a direct request to the provider you choose.">
      <h2>What Tracal stores</h2>
      <p>Meals, nutrition values, goals, protected meal photos, provider preferences, and AI usage records are stored locally in the app container on your iPhone. Tracal has no account system, analytics service, advertising SDK, remote meal database, or CloudKit sync.</p>

      <h2>API keys</h2>
      <p>Provider API keys are stored in Apple Keychain using device-only protection and are available only while the device is unlocked. Keys are not stored in meal records, UserDefaults, backups, app logs, or the app bundle. A Tracal backup never contains an API key.</p>

      <h2>Optional cloud analysis</h2>
      <p>Local parsing and nutrition-label OCR run first. If you enable a provider and explicitly consent, Tracal sends the current meal description or a sanitized meal photo directly from your iPhone to the selected provider: OpenAI, Anthropic, or Google Gemini. A sanitized photo is orientation-normalized, resized, re-encoded, and stripped of ordinary photo metadata before upload.</p>
      <div className="callout"><p>Tracal does not receive or proxy these requests. Your provider account, API key, contract, settings, region, and service tier determine how the provider processes and retains the request.</p></div>

      <h2>Provider practices</h2>
      <ul>
        <li><a href="https://platform.openai.com/docs/models/default-usage-policies-by-endpoint">OpenAI API data controls</a> state that API content is not used to improve models unless the account opts in and that abuse-monitoring logs are ordinarily retained for up to 30 days, subject to exceptions and account controls.</li>
        <li><a href="https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data">Anthropic API retention</a> states that API inputs and outputs are ordinarily deleted within 30 days, with exceptions for safety, law, longer-lived features, or a different agreement.</li>
        <li><a href="https://ai.google.dev/gemini-api/terms">Gemini API terms</a> and <a href="https://ai.google.dev/gemini-api/docs/zdr">retention guidance</a> explain that paid-service prompts and responses are not used to improve Google products, while retention and free-service treatment depend on the service and account.</li>
      </ul>
      <p>These providers can change their practices. Review the terms that apply to your account before sending sensitive content.</p>

      <h2>Usage and cost records</h2>
      <p>Tracal stores provider name, model, request identifier, timestamp, token counts, result status, and estimated cost locally. Meal text and photos are not copied into usage records. Cost figures are estimates; provider dashboards are authoritative.</p>

      <h2>Backups and deletion</h2>
      <p>You choose where exported backup files go. They may contain meals, goals, photos, and usage history, but never API keys. You can reset usage history, remove individual provider keys, or delete all local Tracal data in Settings. Deleting data in Tracal does not delete records a provider may hold; use that provider’s controls for those records.</p>

      <h2>Apple</h2>
      <p>Apple processes the App Store purchase, refunds, and related commerce information under Apple’s own policies. Tracal does not receive payment-card details.</p>

      <h2>Children and health information</h2>
      <p>Tracal is intended for people aged 13 and older. Nutrition estimates are not medical advice. Do not submit information you are not authorized to share, including another person’s health information.</p>

      <h2>Contact</h2>
      <p>For privacy questions, contact the developer through <a href="https://www.linkedin.com/in/ajay-pawriya/">Ajay Pawriya on LinkedIn</a>.</p>
    </LegalPage>
  );
}
