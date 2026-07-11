import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Support" };

export default function SupportPage() {
  return (
    <LegalPage title="Support" summary="Start with the checks below. If the issue remains, send the app version, iOS version, provider, and the exact error message—never your API key.">
      <h2>A cloud provider is not working</h2>
      <ol>
        <li>Open Settings in Tracal and confirm the intended provider is selected.</li>
        <li>Paste a valid API key, enable consent, then tap Save and test.</li>
        <li>Confirm the provider account has API access, sufficient balance, and an appropriate spending limit.</li>
        <li>Check that the configured model is available to that account.</li>
      </ol>
      <p>ChatGPT, Claude, and Gemini consumer subscriptions are separate from developer API access. See <Link href="/provider-billing">provider billing</Link>.</p>

      <h2>A meal was not saved</h2>
      <p>Tracal rejects incomplete, non-food, truncated, quota-limited, and invalid cloud results instead of saving unreliable nutrition. Try clearer text or a better-lit photo. Explicit nutrition values and nutrition-label OCR can work without a provider key.</p>

      <h2>Backup or restore</h2>
      <p>Use Settings to export a <code>.tracalbackup</code> file to a location you control. Import adds records not already present. Provider keys are intentionally excluded and must be pasted again.</p>

      <h2>Delete data</h2>
      <p>Settings lets you reset usage history, delete provider keys, or delete all local Tracal records. Provider-side request records must be managed through the provider account.</p>

      <h2>Contact</h2>
      <p>Contact <a href="https://www.linkedin.com/in/ajay-pawriya/">Ajay Pawriya on LinkedIn</a> or open a public issue on <a href="https://github.com/ajayveyron/tracal/issues">GitHub</a>. Do not include an API key, meal photo, health information, or full provider request in a public issue.</p>
    </LegalPage>
  );
}
