const MEBIBYTE = 1024 * 1024;
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "::1", "localhost"]);

export class ConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ConfigurationError";
  }
}

/** Loads runtime-only configuration. Secrets remain server-side and are never logged. */
export function loadConfig(env = process.env) {
  const isCloudRun = Boolean(env.K_SERVICE);
  const host = env.HOST || (isCloudRun ? "0.0.0.0" : "127.0.0.1");
  const nodeEnvironment = env.NODE_ENV || "development";
  const allowInsecureLocal = env.TRACAL_ALLOW_INSECURE_LOCAL === "true";
  const mockModel = env.TRACAL_MOCK_MODEL === "true";
  const deviceTokenHash = normalizeTokenHash(env.TRACAL_DEVICE_TOKEN_SHA256);
  const vertexApiKey = optionalSecret(env.TRACAL_VERTEX_API_KEY);
  const geminiApiKey = optionalSecret(env.TRACAL_GEMINI_API_KEY, "TRACAL_GEMINI_API_KEY");

  if (vertexApiKey && geminiApiKey) {
    throw new ConfigurationError(
      "TRACAL_VERTEX_API_KEY and TRACAL_GEMINI_API_KEY are mutually exclusive.",
    );
  }

  if (allowInsecureLocal && nodeEnvironment === "production") {
    throw new ConfigurationError(
      "TRACAL_ALLOW_INSECURE_LOCAL cannot be enabled in production.",
    );
  }

  if (mockModel && nodeEnvironment === "production") {
    throw new ConfigurationError(
      "TRACAL_MOCK_MODEL cannot be enabled in production.",
    );
  }

  if (allowInsecureLocal && !LOOPBACK_HOSTS.has(host)) {
    throw new ConfigurationError(
      "Insecure local mode can only bind to a loopback host.",
    );
  }

  if (!deviceTokenHash && !allowInsecureLocal) {
    throw new ConfigurationError(
      "Set TRACAL_DEVICE_TOKEN_SHA256 or explicitly enable loopback-only local development.",
    );
  }

  // Gemini Developer API only needs an API key. Vertex modes need a project id
  // (ADC / Express). Vercel deploys typically use TRACAL_GEMINI_API_KEY.
  // Mock mode is local/simulator only and skips provider credentials.
  const inferenceProvider = mockModel
    ? "mock"
    : geminiApiKey
      ? "geminiDeveloper"
      : vertexApiKey
        ? "vertexExpress"
        : "vertexADC";
  const project =
    inferenceProvider === "geminiDeveloper" || inferenceProvider === "mock"
      ? optionalText(env.GOOGLE_CLOUD_PROJECT) ||
        (inferenceProvider === "mock" ? "mock-local" : "gemini-developer")
      : requireText(env.GOOGLE_CLOUD_PROJECT, "GOOGLE_CLOUD_PROJECT");

  return Object.freeze({
    host,
    port: integer(env.PORT, 8080, 1, 65_535, "PORT"),
    nodeEnvironment,
    project,
    location: env.GOOGLE_CLOUD_LOCATION || "global",
    model:
      env.TRACAL_MODEL ||
      env.VERTEX_MODEL ||
      (mockModel ? "mock-meal-v1" : "gemini-3-flash-preview"),
    vertexApiKey,
    geminiApiKey,
    mockModel,
    inferenceProvider,
    deviceTokenHash,
    allowInsecureLocal,
    maxBodyBytes: integer(
      env.TRACAL_MAX_BODY_BYTES,
      8 * MEBIBYTE,
      1_024,
      12 * MEBIBYTE,
      "TRACAL_MAX_BODY_BYTES",
    ),
    maxImageBytes: integer(
      env.TRACAL_MAX_IMAGE_BYTES,
      5 * MEBIBYTE,
      1_024,
      8 * MEBIBYTE,
      "TRACAL_MAX_IMAGE_BYTES",
    ),
    modelTimeoutMs: integer(
      env.TRACAL_MODEL_TIMEOUT_MS,
      25_000,
      1_000,
      55_000,
      "TRACAL_MODEL_TIMEOUT_MS",
    ),
  });
}

function optionalSecret(value, name = "TRACAL_VERTEX_API_KEY") {
  if (value === undefined || value === "") return null;
  const normalized = String(value).trim();
  if (normalized.length < 20 || normalized.length > 512) {
    throw new ConfigurationError(`${name} has an invalid length.`);
  }
  return normalized;
}

function normalizeTokenHash(value) {
  if (value === undefined || value === "") return null;
  const normalized = String(value).trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(normalized)) {
    throw new ConfigurationError(
      "TRACAL_DEVICE_TOKEN_SHA256 must be a 64-character hexadecimal SHA-256 digest.",
    );
  }
  return normalized;
}

function optionalText(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized === "" ? null : normalized;
}

function requireText(value, name) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new ConfigurationError(`${name} is required.`);
  }
  return value.trim();
}

function integer(value, fallback, minimum, maximum, name) {
  if (value === undefined || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new ConfigurationError(
      `${name} must be an integer from ${minimum} through ${maximum}.`,
    );
  }
  return parsed;
}
