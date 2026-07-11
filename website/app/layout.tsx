import type { Metadata } from "next";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://tracal.vercel.app"),
  title: {
    default: "Tracal — Private calorie tracking for iPhone",
    template: "%s — Tracal",
  },
  description: "Log meals by text or photo while keeping your meal history on your iPhone. Optional direct AI analysis uses your own provider API key.",
  applicationName: "Tracal",
  category: "health",
  openGraph: {
    title: "Tracal — Log the meal. Keep the data.",
    description: "Private calorie tracking for iPhone with local meal history and optional direct BYOK analysis.",
    url: "/",
    siteName: "Tracal",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Tracal — Log the meal. Keep the data.",
    description: "Private calorie tracking for iPhone with local meal history and optional direct BYOK analysis.",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <SiteHeader />
        {children}
        <SiteFooter />
      </body>
    </html>
  );
}
