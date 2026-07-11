import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Terms of use" };

export default function TermsPage() {
  return (
    <LegalPage title="Terms of use" summary="These terms cover the Tracal iPhone app and website. Provider services remain governed by their own terms.">
      <h2>Using Tracal</h2>
      <p>You may use Tracal for personal meal and nutrition tracking if you comply with applicable law, Apple’s terms, and these terms. Do not misuse the app, interfere with its operation, or use it to submit content you do not have the right to process.</p>

      <h2>Nutrition estimates</h2>
      <p>All calorie, macro, and nutrition values are estimates. Results can be inaccurate, incomplete, or unsuitable for your circumstances. Review and correct entries. Tracal is not a medical device and does not provide diagnosis, treatment, or professional medical or dietary advice. Seek a qualified professional for health decisions.</p>

      <h2>App purchase</h2>
      <p>Tracal is sold as a one-time paid App Store download. Apple handles payment, regional pricing, taxes, purchase history, and refund decisions. The purchase does not include an OpenAI, Anthropic, or Gemini API account, credits, or usage.</p>

      <h2>Provider services</h2>
      <p>Cloud analysis is optional. If you connect an API key, you are responsible for the provider account, authorization, security, limits, charges, and compliance with that provider’s terms. Consumer subscriptions such as ChatGPT, Claude, or Gemini subscriptions do not necessarily include API access. Provider availability, models, pricing, and output may change independently of Tracal.</p>

      <h2>Your content and device</h2>
      <p>You retain responsibility for content you enter or photograph. Most Tracal data exists only on your device, so you are responsible for device access and backups. Removing the app may remove local records. API keys use device-only Keychain protection and are excluded from Tracal backups.</p>

      <h2>Availability and warranty</h2>
      <p>Tracal is provided on an “as is” and “as available” basis to the extent permitted by law. No guarantee is made that the app, Apple Intelligence, or a third-party provider will always be available or error-free. Nothing in these terms excludes rights that cannot legally be excluded.</p>

      <h2>Liability</h2>
      <p>To the maximum extent permitted by law, the developer is not liable for indirect or consequential loss, provider charges, data loss, or decisions made from nutrition estimates. Your statutory consumer rights remain unaffected.</p>

      <h2>Changes</h2>
      <p>These terms may be updated when the app, law, or provider relationships change. The effective date on this page identifies the current version.</p>

      <h2>Contact</h2>
      <p>Questions can be sent through <a href="https://www.linkedin.com/in/ajay-pawriya/">Ajay Pawriya on LinkedIn</a>.</p>
    </LegalPage>
  );
}
