import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Refunds" };

export default function RefundsPage() {
  return (
    <LegalPage title="Refunds" summary="Apple sells Tracal through the App Store and decides App Store refund requests.">
      <h2>Request an App Store refund</h2>
      <p>Sign in at <a href="https://reportaproblem.apple.com/">Apple’s Report a Problem</a>, choose Tracal, and follow Apple’s refund process. Eligibility and timing are controlled by Apple and local consumer law.</p>

      <h2>Provider charges are separate</h2>
      <p>OpenAI, Anthropic, and Gemini API charges are not collected by Tracal or Apple as part of the app purchase. Questions about those charges must be handled through the relevant provider account and support process.</p>

      <h2>Revoked purchases</h2>
      <p>Tracal checks Apple’s verified app transaction and can react if Apple revokes a purchase. Temporary StoreKit or network outages do not intentionally block legitimate customers.</p>
    </LegalPage>
  );
}
