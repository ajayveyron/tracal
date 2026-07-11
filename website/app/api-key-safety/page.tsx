import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "API key safety" };

export default function APIKeySafetyPage() {
  return (
    <LegalPage title="API key safety" summary="Paste only a dedicated provider API key. Never share it with support, screenshots, or public issue reports.">
      <h2>Use a dedicated key</h2>
      <p>Create a separate API project or key for Tracal in the provider’s own developer console. Apply the lowest practical spending cap, quota, and model permissions. Do not reuse a production or workplace key.</p>

      <h2>How Tracal stores it</h2>
      <p>The key is stored in Apple Keychain with <code>WhenUnlockedThisDeviceOnly</code> protection. It is not synced, backed up, placed in UserDefaults or SwiftData, written to logs, or included in exports.</p>

      <h2>Where it goes</h2>
      <p>Tracal uses the key only for HTTPS requests to the official API origin of the provider you selected. It does not send the key to Tracal, another provider, an analytics service, or an intermediary router.</p>

      <h2>If a key may be exposed</h2>
      <ol>
        <li>Revoke it immediately in the provider console.</li>
        <li>Review provider usage and billing for unexpected requests.</li>
        <li>Create a replacement key with a spending limit.</li>
        <li>Delete the old key in Tracal, then paste and test the replacement.</li>
      </ol>

      <h2>Support will never ask for it</h2>
      <p>Do not send keys in email, LinkedIn messages, screenshots, crash reports, or GitHub issues. A legitimate support response does not require the full key.</p>
    </LegalPage>
  );
}
