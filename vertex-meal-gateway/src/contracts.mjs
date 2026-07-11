import { randomUUID } from "node:crypto";

const TEXT_SOURCES = new Set(["typedText"]);
const PHOTO_SOURCES = new Set(["cameraPhoto", "photoLibrary"]);
const IMAGE_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class GatewayError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = "GatewayError";
    this.status = status;
    this.code = code;
  }
}

export const MEAL_RESPONSE_JSON_SCHEMA = Object.freeze({
  type: "object",
  additionalProperties: false,
  required: ["containsFoodOrDrink", "title", "reviewReason", "items"],
  properties: {
    containsFoodOrDrink: {
      type: "boolean",
    },
    title: {
      type: "string",
    },
    reviewReason: {
      type: "string",
    },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "name",
          "quantity",
          "unit",
          "estimatedGrams",
          "nutrition",
          "identificationConfidence",
          "portionConfidence",
          "assumptions",
        ],
        properties: {
          name: { type: "string" },
          quantity: { type: "number" },
          unit: {
            type: "string",
          },
          estimatedGrams: {
            type: "number",
          },
          nutrition: {
            type: "object",
            additionalProperties: false,
            required: [
              "caloriesKcal",
              "proteinGrams",
              "carbohydrateGrams",
              "fatGrams",
            ],
            properties: {
              caloriesKcal: { type: "number" },
              proteinGrams: { type: "number" },
              carbohydrateGrams: { type: "number" },
              fatGrams: { type: "number" },
            },
          },
          identificationConfidence: { type: "number" },
          portionConfidence: { type: "number" },
          assumptions: {
            type: "array",
            items: { type: "string" },
          },
        },
      },
    },
  },
});

export function parseAnalyzeRequest(value, config) {
  const body = object(value, "Request body");
  if (body.schemaVersion !== 1) {
    throw badRequest("schemaVersion must be 1.");
  }

  const id = uuid(body.analysisId, "analysisId");
  const loggedAt = isoDate(body.loggedAt, "loggedAt");
  const source = shortString(body.source, "source", 32);
  const input = object(body.input, "input");
  const kind = shortString(input.kind, "input.kind", 16);

  if (kind === "text") {
    if (!TEXT_SOURCES.has(source)) {
      throw badRequest("Text analysis source must be typedText.");
    }
    if (input.image !== undefined && input.image !== null) {
      throw badRequest("Text input cannot contain an image.");
    }
    return {
      kind: "text",
      id,
      loggedAt,
      source,
      text: shortString(input.text, "input.text", 4_000),
    };
  }

  if (kind !== "photo") {
    throw badRequest("input.kind must be text or photo.");
  }
  if (!PHOTO_SOURCES.has(source)) {
    throw badRequest("Image analysis source must be cameraPhoto or photoLibrary.");
  }

  const image = object(input.image, "input.image");
  const mimeType = shortString(image.mimeType, "input.image.mimeType", 64).toLowerCase();
  if (!IMAGE_MIME_TYPES.has(mimeType)) {
    throw new GatewayError(415, "unsupported_image", "Image must be JPEG, PNG, or WebP.");
  }

  const base64 = strictBase64(image.bytesBase64, "input.image.bytesBase64");
  const byteLength = Buffer.byteLength(base64, "base64");
  if (byteLength === 0 || byteLength > config.maxImageBytes) {
    throw new GatewayError(413, "image_too_large", "Image exceeds the configured limit.");
  }
  const pixelWidth = requestInteger(image.pixelWidth, "input.image.pixelWidth", 1, 12_000);
  const pixelHeight = requestInteger(image.pixelHeight, "input.image.pixelHeight", 1, 12_000);
  if (pixelWidth * pixelHeight > 64_000_000) {
    throw badRequest("Image pixel dimensions are too large.");
  }

  const hint = input.hint === undefined || input.hint === null
    ? null
    : shortString(input.hint, "input.hint", 500);

  return {
    kind: "image",
    id,
    loggedAt,
    source,
    image: { base64, mimeType, byteLength, pixelWidth, pixelHeight },
    hint,
  };
}

export function makeAnalyzedMealDraft(modelValue, input, modelName) {
  const value = object(modelValue, "Model response");
  const containsFoodOrDrink = modelBoolean(value.containsFoodOrDrink);
  if (!containsFoodOrDrink) {
    throw new GatewayError(
      422,
      "no_food_detected",
      "No food or drink was found in that photo.",
    );
  }
  const rawItems = array(value.items, "items", 1, 20);
  const items = rawItems.map((rawItem, index) => normalizeItem(rawItem, index));

  const totals = items.reduce(
    (result, item) => ({
      caloriesKcal: result.caloriesKcal + item.caloriesKcal,
      proteinGrams: result.proteinGrams + item.proteinG,
      carbohydrateGrams:
        result.carbohydrateGrams + item.carbohydrateG,
      fatGrams: result.fatGrams + item.fatG,
    }),
    { caloriesKcal: 0, proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0 },
  );
  if (
    totals.caloriesKcal > 50_000 ||
    totals.proteinGrams > 5_000 ||
    totals.carbohydrateGrams > 5_000 ||
    totals.fatGrams > 5_000
  ) {
    throw invalidModelResponse();
  }

  // Uncertainty is metadata, not nutrition. Gemini may need a few sentences to
  // reconcile a user's portion hint with what is visible; keep that bounded
  // without discarding an otherwise valid meal estimate.
  const reviewReason = optionalTrimmed(value.reviewReason, 500);
  return {
    schemaVersion: 1,
    analysisId: input.id,
    title: shortModelString(value.title, 120),
    items,
    needsReview: true,
    reviewReason: reviewReason || "Portions are estimated from the provided input.",
    promptVersion: "tracal-meal-v1",
    modelVersion: modelName,
  };
}

function normalizeItem(rawValue, index) {
  const value = object(rawValue, `items[${index}]`);
  const nutrition = object(value.nutrition, `items[${index}].nutrition`);
  const estimatedGrams = modelNumber(value.estimatedGrams, 0, 100_000);
  return {
    id: randomUUID(),
    name: shortModelString(value.name, 120),
    amount: modelNumber(value.quantity, 0.01, 10_000),
    unit: shortModelString(value.unit, 32),
    estimatedGrams: estimatedGrams === 0 ? null : estimatedGrams,
    caloriesKcal: modelNumber(nutrition.caloriesKcal, 0, 20_000),
    proteinG: modelNumber(nutrition.proteinGrams, 0, 2_000),
    carbohydrateG: modelNumber(nutrition.carbohydrateGrams, 0, 2_000),
    fatG: modelNumber(nutrition.fatGrams, 0, 2_000),
    identificationConfidence: modelNumber(value.identificationConfidence, 0, 1),
    portionConfidence: modelNumber(value.portionConfidence, 0, 1),
    assumptions: array(value.assumptions, "assumptions", 0, 8).map((assumption) =>
      shortModelString(assumption, 200),
    ),
  };
}

function badRequest(message) {
  return new GatewayError(400, "invalid_request", message);
}

function invalidModelResponse() {
  return new GatewayError(
    502,
    "invalid_model_response",
    "The inference provider returned an unusable meal estimate.",
  );
}

function object(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    if (label === "Model response" || label.startsWith("items[")) {
      throw invalidModelResponse();
    }
    throw badRequest(`${label} must be an object.`);
  }
  return value;
}

function array(value, label, minimum, maximum) {
  if (!Array.isArray(value) || value.length < minimum || value.length > maximum) {
    if (label === "items" || label === "assumptions") throw invalidModelResponse();
    throw badRequest(`${label} has an invalid number of values.`);
  }
  return value;
}

function shortString(value, field, maximum) {
  if (typeof value !== "string") throw badRequest(`${field} must be text.`);
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maximum) {
    throw badRequest(`${field} must contain 1 to ${maximum} characters.`);
  }
  return trimmed;
}

function shortModelString(value, maximum) {
  if (typeof value !== "string") throw invalidModelResponse();
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maximum) throw invalidModelResponse();
  return trimmed;
}

function modelBoolean(value) {
  if (typeof value !== "boolean") throw invalidModelResponse();
  return value;
}

function optionalTrimmed(value, maximum) {
  if (typeof value !== "string") throw invalidModelResponse();
  const trimmed = value.trim();
  if (trimmed.length > maximum) throw invalidModelResponse();
  return trimmed;
}

function modelNumber(value, minimum, maximum) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw invalidModelResponse();
  }
  return value;
}

function isoDate(value, field) {
  const text = shortString(value, field, 40);
  const date = new Date(text);
  if (
    !Number.isFinite(date.getTime()) ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$/.test(text)
  ) {
    throw badRequest(`${field} must be an ISO-8601 UTC timestamp.`);
  }
  return text;
}

function uuid(value, field) {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw badRequest(`${field} must be a UUID.`);
  }
  return value.toLowerCase();
}

function strictBase64(value, field) {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value)
  ) {
    throw badRequest(`${field} must be standard padded base64.`);
  }
  return value;
}

function requestInteger(value, field, minimum, maximum) {
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw badRequest(`${field} must be an integer from ${minimum} through ${maximum}.`);
  }
  return value;
}
