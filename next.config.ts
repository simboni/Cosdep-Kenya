import type { NextConfig } from "next";

// When deploying to GitHub Pages under a project sub-path (e.g.
// https://<user>.github.io/peter-misiati/), CI sets PAGES_BASE_PATH so Next
// prefixes asset and internal-link URLs correctly. Left empty for local dev
// and for root-domain hosts (Vercel / Cloudflare / a custom domain).
const basePath = process.env.PAGES_BASE_PATH ?? "";

const nextConfig: NextConfig = {
  // Static HTML export — deploys to any static host.
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  ...(basePath ? { basePath } : {}),
};

export default nextConfig;
