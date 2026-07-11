import { loadConfig } from "../src/config.mjs";
import { GatewayError } from "../src/contracts.mjs";
import { handleGatewayRequest } from "../src/server.mjs";
import { createMealAnalysisService } from "../src/service.mjs";
import { createGoogleMealModel } from "../src/vertex-client.mjs";

let cached;

function getRuntime() {
  if (cached) return cached;
  const config = loadConfig();
  const model = createGoogleMealModel(config);
  const service = createMealAnalysisService({ model, config });
  cached = { config, service };
  return cached;
}

/**
 * Vercel Node serverless entry. Rewrites send /healthz and /v1/analyze here.
 * Prefer a Gemini API key or Vertex Express key on Vercel; ADC is for Cloud Run.
 */
export default async function handler(req, res) {
  try {
    const { config, service } = getRuntime();
    const host = req.headers.host || "gateway.local";
    const url = new URL(req.url || "/", `https://${host}`);
    const pathname = normalizePathname(url.pathname);

    const result = await handleGatewayRequest({
      method: req.method || "GET",
      pathname,
      authorization: headerValue(req.headers.authorization),
      contentType: headerValue(req.headers["content-type"]) || "",
      readJsonBody: () => readVercelJsonBody(req, config.maxBodyBytes),
      service,
      config,
    });

    for (const [key, value] of Object.entries(result.headers || {})) {
      res.setHeader(key, value);
    }
    res.statusCode = result.status;
    if (result.body == null) {
      res.end();
      return;
    }
    res.end(JSON.stringify(result.body));
  } catch (error) {
    const safe =
      error instanceof GatewayError
        ? error
        : new GatewayError(500, "internal_error", "The request could not be completed.");
    res.statusCode = safe.status;
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(
      JSON.stringify({
        error: { code: safe.code, message: safe.message },
      }),
    );
  }
}

function normalizePathname(pathname) {
  if (pathname === "/api" || pathname === "/api/") return "/";
  if (pathname.startsWith("/api/")) {
    const stripped = pathname.slice(4);
    return stripped.startsWith("/") ? stripped : `/${stripped}`;
  }
  return pathname || "/";
}

function headerValue(value) {
  if (Array.isArray(value)) return value[0];
  return value;
}

async function readVercelJsonBody(req, limit) {
  if (req.body != null && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body;
  }

  if (typeof req.body === "string") {
    if (Buffer.byteLength(req.body, "utf8") > limit) {
      throw new GatewayError(413, "payload_too_large", "Request exceeds the configured limit.");
    }
    if (!req.body) {
      throw new GatewayError(400, "invalid_json", "Request body is required.");
    }
    try {
      return JSON.parse(req.body);
    } catch {
      throw new GatewayError(400, "invalid_json", "Request body must be valid JSON.");
    }
  }

  if (Buffer.isBuffer(req.body)) {
    if (req.body.length > limit) {
      throw new GatewayError(413, "payload_too_large", "Request exceeds the configured limit.");
    }
    if (req.body.length === 0) {
      throw new GatewayError(400, "invalid_json", "Request body is required.");
    }
    try {
      return JSON.parse(req.body.toString("utf8"));
    } catch {
      throw new GatewayError(400, "invalid_json", "Request body must be valid JSON.");
    }
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buf.length;
    if (size > limit) {
      throw new GatewayError(413, "payload_too_large", "Request exceeds the configured limit.");
    }
    chunks.push(buf);
  }

  if (size === 0) {
    throw new GatewayError(400, "invalid_json", "Request body is required.");
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new GatewayError(400, "invalid_json", "Request body must be valid JSON.");
  }
}
