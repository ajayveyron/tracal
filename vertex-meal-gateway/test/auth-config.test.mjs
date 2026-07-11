import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { isAuthorized } from "../src/auth.mjs";
import { ConfigurationError, loadConfig } from "../src/config.mjs";

const token = "q".repeat(43);
const tokenHash = createHash("sha256").update(token).digest("hex");

test("bearer token is checked against only its configured SHA-256 digest", () => {
  const config = { deviceTokenHash: tokenHash, allowInsecureLocal: false };
  assert.equal(isAuthorized(`Bearer ${token}`, config), true);
  assert.equal(isAuthorized("Bearer wrong-token-that-is-long-enough-000000", config), false);
  assert.equal(isAuthorized(undefined, config), false);
});

test("config requires a device digest unless local bypass is explicit", () => {
  assert.throws(
    () => loadConfig({ GOOGLE_CLOUD_PROJECT: "project" }),
    ConfigurationError,
  );

  const config = loadConfig({
    GOOGLE_CLOUD_PROJECT: "project",
    TRACAL_ALLOW_INSECURE_LOCAL: "true",
  });
  assert.equal(config.host, "127.0.0.1");
  assert.equal(config.allowInsecureLocal, true);
});

test("insecure bypass cannot bind externally or run in production", () => {
  assert.throws(
    () =>
      loadConfig({
        GOOGLE_CLOUD_PROJECT: "project",
        TRACAL_ALLOW_INSECURE_LOCAL: "true",
        HOST: "0.0.0.0",
      }),
    ConfigurationError,
  );
  assert.throws(
    () =>
      loadConfig({
        GOOGLE_CLOUD_PROJECT: "project",
        TRACAL_ALLOW_INSECURE_LOCAL: "true",
        NODE_ENV: "production",
      }),
    ConfigurationError,
  );
});

test("Vertex Express API key is accepted without being transformed", () => {
  const apiKey = "test-vertex-express-api-key-value";
  const config = loadConfig({
    GOOGLE_CLOUD_PROJECT: "project",
    TRACAL_DEVICE_TOKEN_SHA256: tokenHash,
    TRACAL_VERTEX_API_KEY: apiKey,
  });
  assert.equal(config.vertexApiKey, apiKey);
  assert.equal(config.inferenceProvider, "vertexExpress");
});

test("Gemini Developer API mode is explicit and separate from Vertex modes", () => {
  const apiKey = "test-gemini-developer-api-key-value";
  const config = loadConfig({
    GOOGLE_CLOUD_PROJECT: "project",
    TRACAL_DEVICE_TOKEN_SHA256: tokenHash,
    TRACAL_GEMINI_API_KEY: apiKey,
  });
  assert.equal(config.geminiApiKey, apiKey);
  assert.equal(config.vertexApiKey, null);
  assert.equal(config.inferenceProvider, "geminiDeveloper");

  assert.throws(
    () =>
      loadConfig({
        GOOGLE_CLOUD_PROJECT: "project",
        TRACAL_DEVICE_TOKEN_SHA256: tokenHash,
        TRACAL_GEMINI_API_KEY: apiKey,
        TRACAL_VERTEX_API_KEY: "test-vertex-express-api-key-value",
      }),
    ConfigurationError,
  );
});

test("Gemini Developer API mode does not require GOOGLE_CLOUD_PROJECT", () => {
  const apiKey = "test-gemini-developer-api-key-value";
  const config = loadConfig({
    TRACAL_DEVICE_TOKEN_SHA256: tokenHash,
    TRACAL_GEMINI_API_KEY: apiKey,
  });
  assert.equal(config.inferenceProvider, "geminiDeveloper");
  assert.equal(config.project, "gemini-developer");
});

test("mock model mode is local-only and skips provider credentials", () => {
  const config = loadConfig({
    TRACAL_ALLOW_INSECURE_LOCAL: "true",
    TRACAL_MOCK_MODEL: "true",
  });
  assert.equal(config.inferenceProvider, "mock");
  assert.equal(config.mockModel, true);
  assert.equal(config.model, "mock-meal-v1");

  assert.throws(
    () =>
      loadConfig({
        TRACAL_ALLOW_INSECURE_LOCAL: "true",
        TRACAL_MOCK_MODEL: "true",
        NODE_ENV: "production",
      }),
    ConfigurationError,
  );
});
