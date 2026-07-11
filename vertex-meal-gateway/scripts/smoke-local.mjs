#!/usr/bin/env node
/**
 * Hits a running local gateway (/healthz + /v1/analyze).
 * Expects: TRACAL_ALLOW_INSECURE_LOCAL mock or token-authenticated gateway on :8080.
 */
const base = (process.env.TRACAL_GATEWAY_BASE_URL || "http://127.0.0.1:8080").replace(
  /\/$/,
  "",
);
const token = process.env.TRACAL_GATEWAY_DEVICE_TOKEN || "";

const health = await fetch(`${base}/healthz`);
if (!health.ok) {
  console.error("healthz failed", health.status);
  process.exit(1);
}
console.log("healthz ok");

const headers = { "content-type": "application/json" };
if (token) headers.authorization = `Bearer ${token}`;

const body = {
  schemaVersion: 1,
  analysisId: "4fd883be-1727-4b88-96e1-78c2ba783573",
  source: "typedText",
  loggedAt: new Date().toISOString(),
  input: {
    kind: "text",
    text: "Two masala dosas with coconut chutney and one small filter coffee",
    hint: null,
    image: null,
  },
};

const analyze = await fetch(`${base}/v1/analyze`, {
  method: "POST",
  headers,
  body: JSON.stringify(body),
});
const json = await analyze.json();
if (!analyze.ok) {
  console.error("analyze failed", analyze.status, json);
  process.exit(1);
}
if (!json.title || !Array.isArray(json.items) || json.items.length === 0) {
  console.error("analyze response missing meal fields", json);
  process.exit(1);
}
const kcal = json.items.reduce((sum, item) => sum + (item.caloriesKcal || 0), 0);
console.log(
  JSON.stringify({
    event: "smoke_ok",
    title: json.title,
    items: json.items.length,
    caloriesKcal: kcal,
    modelVersion: json.modelVersion,
  }),
);
