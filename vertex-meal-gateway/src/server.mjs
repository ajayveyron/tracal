import { createServer as createNodeServer } from "node:http";
import { randomUUID } from "node:crypto";
import { isAuthorized } from "./auth.mjs";
import { GatewayError } from "./contracts.mjs";

/**
 * Shared request core used by the local Node server and the Vercel adapter.
 * `readJsonBody` must already return a parsed object for POST /v1/analyze.
 */
export async function handleGatewayRequest({
  method,
  pathname,
  authorization,
  contentType,
  readJsonBody,
  service,
  config,
  logger = defaultLogger,
}) {
  const traceId = randomUUID();
  const startedAt = Date.now();
  const headers = {
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
    "X-Request-ID": traceId,
  };

  try {
    if (method === "GET" && pathname === "/healthz") {
      return jsonResult(200, { status: "ok" }, headers);
    }

    if (method === "OPTIONS") {
      return {
        status: 204,
        headers: {
          ...headers,
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Authorization, Content-Type, Idempotency-Key",
          "Access-Control-Max-Age": "86400",
        },
        body: null,
      };
    }

    if (method !== "POST" || pathname !== "/v1/analyze") {
      throw new GatewayError(404, "not_found", "Route not found.");
    }

    if (!isAuthorized(authorization, config)) {
      throw new GatewayError(401, "unauthorized", "Authorization is required.");
    }

    if (!/^application\/json(?:\s*;|$)/i.test(contentType || "")) {
      throw new GatewayError(415, "unsupported_media_type", "Use application/json.");
    }

    const body = await readJsonBody();
    const draft = await service.analyze(body);
    logger({
      event: "request_completed",
      traceId,
      route: "/v1/analyze",
      status: 200,
      durationMs: Date.now() - startedAt,
    });
    return jsonResult(200, draft, headers);
  } catch (error) {
    const safe = safeError(error);
    logger({
      event: "request_failed",
      traceId,
      route: pathname === "/v1/analyze" ? "/v1/analyze" : "other",
      status: safe.status,
      durationMs: Date.now() - startedAt,
      errorType: error?.name || "Error",
    });
    return jsonResult(
      safe.status,
      { error: { code: safe.code, message: safe.message, traceId } },
      headers,
    );
  }
}

export function createGatewayServer({ service, config, logger = defaultLogger }) {
  const server = createNodeServer(async (request, response) => {
    const url = new URL(request.url || "/", "http://gateway.local");
    const result = await handleGatewayRequest({
      method: request.method || "GET",
      pathname: url.pathname,
      authorization: request.headers.authorization,
      contentType: request.headers["content-type"] || "",
      readJsonBody: () => readNodeJsonBody(request, config.maxBodyBytes),
      service,
      config,
      logger,
    });
    writeResult(response, result);
  });

  server.requestTimeout = Math.min(config.modelTimeoutMs + 10_000, 65_000);
  server.headersTimeout = 10_000;
  server.keepAliveTimeout = 5_000;
  return server;
}

async function readNodeJsonBody(request, limit) {
  const declaredLength = Number(request.headers["content-length"]);
  if (Number.isFinite(declaredLength) && declaredLength > limit) {
    throw new GatewayError(413, "payload_too_large", "Request exceeds the configured limit.");
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > limit) {
      throw new GatewayError(413, "payload_too_large", "Request exceeds the configured limit.");
    }
    chunks.push(chunk);
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

function safeError(error) {
  if (error instanceof GatewayError) return error;
  return new GatewayError(500, "internal_error", "The request could not be completed.");
}

function jsonResult(status, body, headers) {
  return { status, headers, body };
}

function writeResult(response, result) {
  if (response.writableEnded) return;
  for (const [key, value] of Object.entries(result.headers || {})) {
    response.setHeader(key, value);
  }
  response.statusCode = result.status;
  if (result.body == null) {
    response.end();
    return;
  }
  response.end(JSON.stringify(result.body));
}

function defaultLogger(record) {
  // Records contain request metadata only. Meal text, image bytes, auth headers,
  // model responses, and raw upstream errors are intentionally never logged.
  console.log(JSON.stringify(record));
}
