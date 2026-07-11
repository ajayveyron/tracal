import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createGatewayServer } from "../src/server.mjs";
import { config as baseConfig, textRequest } from "./fixtures.mjs";

const token = "private-device-token-with-sufficient-entropy";
const tokenHash = createHash("sha256").update(token).digest("hex");

test("HTTP gateway exposes health, enforces auth, and never logs content", async (context) => {
  const logs = [];
  const config = {
    ...baseConfig,
    deviceTokenHash: tokenHash,
    allowInsecureLocal: false,
  };
  const service = {
    async analyze(body) {
      return {
        schemaVersion: 1,
        analysisId: body.analysisId,
        title: "Test meal",
        items: [],
        needsReview: true,
        reviewReason: "Review",
      };
    },
  };
  const server = createGatewayServer({ service, config, logger: (value) => logs.push(value) });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  context.after(() => new Promise((resolve) => server.close(resolve)));
  const address = server.address();
  const origin = `http://127.0.0.1:${address.port}`;

  const health = await fetch(`${origin}/healthz`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: "ok" });

  const unauthorized = await fetch(`${origin}/v1/analyze`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(textRequest),
  });
  assert.equal(unauthorized.status, 401);

  const authorized = await fetch(`${origin}/v1/analyze`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(textRequest),
  });
  assert.equal(authorized.status, 200);
  assert.equal((await authorized.json()).analysisId, textRequest.analysisId);

  const serializedLogs = JSON.stringify(logs);
  assert.doesNotMatch(serializedLogs, /Two bananas/);
  assert.doesNotMatch(serializedLogs, new RegExp(token));
  assert.doesNotMatch(serializedLogs, /Test meal/);
});

test("HTTP gateway rejects an oversized body before analysis", async (context) => {
  let called = false;
  const config = {
    ...baseConfig,
    deviceTokenHash: tokenHash,
    allowInsecureLocal: false,
    maxBodyBytes: 64,
  };
  const server = createGatewayServer({
    config,
    logger: () => {},
    service: {
      async analyze() {
        called = true;
        return {};
      },
    },
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  context.after(() => new Promise((resolve) => server.close(resolve)));
  const address = server.address();

  const response = await fetch(`http://127.0.0.1:${address.port}/v1/analyze`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(textRequest),
  });

  assert.equal(response.status, 413);
  assert.equal(called, false);
});
