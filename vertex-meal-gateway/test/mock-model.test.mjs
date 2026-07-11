import test from "node:test";
import assert from "node:assert/strict";
import { createMockMealModel } from "../src/mock-model.mjs";
import { createMealAnalysisService } from "../src/service.mjs";
import { config as baseConfig, textRequest, photoRequest } from "./fixtures.mjs";

test("mock model returns schema-valid text and photo drafts", async () => {
  const config = { ...baseConfig, model: "mock-meal-v1", modelTimeoutMs: 5_000 };
  const service = createMealAnalysisService({
    model: createMockMealModel(config),
    config,
  });

  const textDraft = await service.analyze({
    ...textRequest,
    input: {
      kind: "text",
      text: "Two masala dosas with coconut chutney and one small filter coffee",
      hint: null,
      image: null,
    },
  });
  assert.equal(textDraft.schemaVersion, 1);
  assert.ok(textDraft.title.toLowerCase().includes("masala"));
  assert.ok(textDraft.items.length >= 1);
  assert.ok(textDraft.items[0].caloriesKcal > 0);

  const photoDraft = await service.analyze(photoRequest);
  assert.equal(photoDraft.schemaVersion, 1);
  assert.ok(photoDraft.items.length >= 1);
  assert.ok(photoDraft.items[0].caloriesKcal > 0);
});
