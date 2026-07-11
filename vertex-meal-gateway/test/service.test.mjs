import test from "node:test";
import assert from "node:assert/strict";
import { createMealAnalysisService } from "../src/service.mjs";
import { GatewayError } from "../src/contracts.mjs";
import { analysisId, config, modelMeal, photoRequest, textRequest } from "./fixtures.mjs";

test("typed analysis returns the exact schema-v1 Swift transport contract", async () => {
  let receivedInput;
  const service = createMealAnalysisService({
    config,
    model: {
      async generate(input) {
        receivedInput = input;
        return modelMeal;
      },
    },
  });

  const response = await service.analyze(textRequest);

  assert.equal(receivedInput.kind, "text");
  assert.equal(receivedInput.text, textRequest.input.text);
  assert.equal(response.schemaVersion, 1);
  assert.equal(response.analysisId, analysisId);
  assert.equal(response.title, modelMeal.title);
  assert.equal(response.needsReview, true);
  assert.equal(response.promptVersion, "tracal-meal-v1");
  assert.equal(response.modelVersion, "gemini-test");
  assert.deepEqual(response.items[0], {
    id: response.items[0].id,
    name: "Banana",
    amount: 2,
    unit: "medium",
    estimatedGrams: 236,
    caloriesKcal: 210,
    proteinG: 2.6,
    carbohydrateG: 54,
    fatG: 0.8,
    identificationConfidence: 0.98,
    portionConfidence: 0.8,
    assumptions: ["Medium bananas"],
  });
  assert.match(response.items[0].id, /^[0-9a-f-]{36}$/);
  assert.equal(Object.hasOwn(response, "loggedAt"), false);
  assert.equal(Object.hasOwn(response, "inputSource"), false);
});

test("photo analysis validates and forwards sanitized inline image metadata", async () => {
  let receivedInput;
  const service = createMealAnalysisService({
    config,
    model: {
      async generate(input) {
        receivedInput = input;
        return modelMeal;
      },
    },
  });

  const response = await service.analyze(photoRequest);

  assert.equal(receivedInput.kind, "image");
  assert.equal(receivedInput.image.base64, photoRequest.input.image.bytesBase64);
  assert.equal(receivedInput.image.mimeType, "image/jpeg");
  assert.equal(receivedInput.image.pixelWidth, 1_200);
  assert.equal(receivedInput.hint, "I ate the whole bowl");
  assert.equal(response.analysisId, analysisId);
});

test("non-food photos return a typed error and never create a meal draft", async () => {
  const service = createMealAnalysisService({
    config,
    model: {
      async generate() {
        return {
          containsFoodOrDrink: false,
          title: "No food detected",
          reviewReason: "The image does not contain food or drink.",
          items: [],
        };
      },
    },
  });

  await assert.rejects(
    service.analyze(photoRequest),
    (error) =>
      error instanceof GatewayError &&
      error.status === 422 &&
      error.code === "no_food_detected",
  );
});

test("bounded uncertainty metadata does not discard valid photo nutrition", async () => {
  const reviewReason = "Estimated from the visible platter and the user's stated portion. ".repeat(5).trim();
  assert.ok(reviewReason.length > 240);
  assert.ok(reviewReason.length <= 500);

  const service = createMealAnalysisService({
    config,
    model: {
      async generate() {
        return { ...modelMeal, reviewReason };
      },
    },
  });

  const response = await service.analyze(photoRequest);

  assert.equal(response.reviewReason, reviewReason);
  assert.equal(response.items[0].caloriesKcal, modelMeal.items[0].nutrition.caloriesKcal);
});

test("malformed or implausible model nutrition is rejected", async () => {
  const service = createMealAnalysisService({
    config,
    model: {
      async generate() {
        return {
          ...modelMeal,
          items: [
            {
              ...modelMeal.items[0],
              nutrition: { ...modelMeal.items[0].nutrition, caloriesKcal: 60_000 },
            },
          ],
        };
      },
    },
  });

  await assert.rejects(
    service.analyze(textRequest),
    (error) => error instanceof GatewayError && error.code === "invalid_model_response",
  );
});

test("invalid schema-v1 input is rejected before calling Vertex", async () => {
  let called = false;
  const service = createMealAnalysisService({
    config,
    model: {
      async generate() {
        called = true;
        return modelMeal;
      },
    },
  });

  await assert.rejects(
    service.analyze({ ...textRequest, schemaVersion: 2 }),
    (error) => error instanceof GatewayError && error.status === 400,
  );
  assert.equal(called, false);
});

test("decoded image payload limit is enforced before calling Vertex", async () => {
  let called = false;
  const service = createMealAnalysisService({
    config: { ...config, maxImageBytes: 4 },
    model: {
      async generate() {
        called = true;
        return modelMeal;
      },
    },
  });

  await assert.rejects(
    service.analyze(photoRequest),
    (error) => error instanceof GatewayError && error.code === "image_too_large",
  );
  assert.equal(called, false);
});

test("analysis has a hard timeout even when the model ignores cancellation", async () => {
  const service = createMealAnalysisService({
    config: { ...config, modelTimeoutMs: 20 },
    model: { generate: () => new Promise(() => {}) },
  });

  await assert.rejects(
    service.analyze(textRequest),
    (error) => error instanceof GatewayError && error.code === "analysis_timeout",
  );
});
