import type { MetadataRoute } from "next";

const paths = ["", "/privacy", "/terms", "/support", "/api-key-safety", "/provider-billing", "/refunds"];

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? "https://tracal.vercel.app";
  return paths.map((path) => ({
    url: `${base}${path}`,
    lastModified: new Date("2026-07-11"),
    changeFrequency: path === "" ? "monthly" : "yearly",
    priority: path === "" ? 1 : 0.6,
  }));
}
