import test from "node:test";
import assert from "node:assert/strict";
import { createGoogleMealModel } from "../src/vertex-client.mjs";
import { config, modelMeal, photoRequest, textRequest } from "./fixtures.mjs";
import { parseAnalyzeRequest } from "../src/contracts.mjs";

test("Google Gen AI client uses structured JSON generation for text", async () => {
  let captured;
  const client = {
    models: {
      async generateContent(request) {
        captured = request;
        return { text: JSON.stringify(modelMeal) };
      },
    },
  };
  const model = createGoogleMealModel(config, { client });

  const result = await model.generate(parseAnalyzeRequest(textRequest, config));

  assert.deepEqual(result, modelMeal);
  assert.equal(captured.model, "gemini-test");
  assert.equal(captured.config.responseMimeType, "application/json");
  assert.equal(captured.config.responseJsonSchema.type, "object");
  assert.ok(captured.config.responseJsonSchema.required.includes("containsFoodOrDrink"));
  assert.equal(captured.config.temperature, 0.1);
  assert.equal(captured.config.maxOutputTokens, 8_192);
  assert.match(captured.contents.parts[0].text, /Two bananas/);
  assert.equal(captured.contents.parts.length, 1);
});

test("Google Gen AI client sends photos as inlineData without changing bytes", async () => {
  let captured;
  const client = {
    models: {
      async generateContent(request) {
        captured = request;
        return { text: JSON.stringify(modelMeal) };
      },
    },
  };
  const model = createGoogleMealModel(config, { client });

  await model.generate(parseAnalyzeRequest(photoRequest, config));

  assert.deepEqual(captured.contents.parts[1], {
    inlineData: {
      mimeType: "image/jpeg",
      data: photoRequest.input.image.bytesBase64,
    },
  });
  assert.match(captured.contents.parts[0].text, /whole bowl/);
  assert.match(captured.contents.parts[0].text, /containsFoodOrDrink false/);
});

test("Google Gen AI client never accepts unstructured response text", async () => {
  const client = {
    models: { generateContent: async () => ({ text: "not json" }) },
  };
  const model = createGoogleMealModel(config, { client });

  await assert.rejects(
    model.generate(parseAnalyzeRequest(textRequest, config)),
    { name: "ModelResponseError" },
  );
});

test("Gemini 3 image analysis uses minimal thinking and retries truncated JSON compactly", async () => {
  const requests = [];
  const client = {
    models: {
      async generateContent(request) {
        requests.push(request);
        if (requests.length === 1) {
          return {
            text: '{"title":"Sushi","items":[',
            candidates: [{ finishReason: "MAX_TOKENS" }],
          };
        }
        return {
          text: JSON.stringify(modelMeal),
          candidates: [{ finishReason: "STOP" }],
        };
      },
    },
  };
  const model = createGoogleMealModel(
    { ...config, model: "gemini-3.5-flash" },
    { client },
  );

  const result = await model.generate(parseAnalyzeRequest(photoRequest, config));

  assert.deepEqual(result, modelMeal);
  assert.equal(requests.length, 2);
  assert.deepEqual(requests[0].config.thinkingConfig, {
    thinkingLevel: "minimal",
    includeThoughts: false,
  });
  assert.equal(requests[0].config.maxOutputTokens, 8_192);
  assert.equal(requests[1].config.maxOutputTokens, 12_288);
  assert.match(requests[1].contents.parts[0].text, /Group visually identical/);
  assert.deepEqual(requests[1].contents.parts[1], requests[0].contents.parts[1]);
});

test("retryable inference statuses use the compact second and final attempt", async () => {
  for (const status of [408, 409, 429, 502]) {
    const requests = [];
    const client = {
      models: {
        async generateContent(request) {
          requests.push(request);
          if (requests.length === 1) {
            throw Object.assign(new Error(`upstream ${status}`), { status });
          }
          return { text: JSON.stringify(modelMeal) };
        },
      },
    };
    const model = createGoogleMealModel(config, { client });

    const result = await model.generate(parseAnalyzeRequest(photoRequest, config));

    assert.deepEqual(result, modelMeal);
    assert.equal(requests.length, 2);
    assert.equal(requests[1].config.maxOutputTokens, 12_288);
    assert.match(requests[1].contents.parts[0].text, /Return compact JSON now/);
    assert.deepEqual(requests[1].contents.parts[1], requests[0].contents.parts[1]);
  }
});

test("safe network failures receive one bounded retry", async () => {
  let calls = 0;
  const networkError = Object.assign(new Error("socket closed"), {
    cause: Object.assign(new Error("connection reset"), { code: "ECONNRESET" }),
  });
  const client = {
    models: {
      async generateContent() {
        calls += 1;
        if (calls === 1) throw networkError;
        return { text: JSON.stringify(modelMeal) };
      },
    },
  };
  const model = createGoogleMealModel(config, { client });

  const result = await model.generate(parseAnalyzeRequest(textRequest, config));

  assert.deepEqual(result, modelMeal);
  assert.equal(calls, 2);
});

test("non-retryable upstream 4xx errors fail without a second request", async () => {
  for (const status of [400, 401, 403, 404, 422]) {
    let calls = 0;
    const client = {
      models: {
        async generateContent() {
          calls += 1;
          throw Object.assign(new Error(`upstream ${status}`), { status });
        },
      },
    };
    const model = createGoogleMealModel(config, { client });

    await assert.rejects(
      model.generate(parseAnalyzeRequest(textRequest, config)),
      {
        name: "GatewayError",
        status: 502,
        code: "inference_unavailable",
      },
    );
    assert.equal(calls, 1);
  }
});

test("abort failures are never retried or wrapped", async () => {
  let calls = 0;
  const abortError = Object.assign(new Error("cancelled"), { name: "AbortError" });
  const model = createGoogleMealModel(config, {
    client: {
      models: {
        async generateContent() {
          calls += 1;
          throw abortError;
        },
      },
    },
  });

  await assert.rejects(
    model.generate(parseAnalyzeRequest(textRequest, config)),
    (error) => error === abortError,
  );
  assert.equal(calls, 1);
});

test("Gemini 2.5 disables thinking for bounded structured extraction", async () => {
  let captured;
  const model = createGoogleMealModel(
    { ...config, model: "gemini-2.5-flash" },
    {
      client: {
        models: {
          async generateContent(request) {
            captured = request;
            return { text: JSON.stringify(modelMeal) };
          },
        },
      },
    },
  );

  await model.generate(parseAnalyzeRequest(textRequest, config));
  assert.deepEqual(captured.config.thinkingConfig, {
    thinkingBudget: 0,
    includeThoughts: false,
  });
});

test("Vertex Express mode passes only the API key, never project or location", () => {
  let options;
  createGoogleMealModel(
    { ...config, vertexApiKey: "test-vertex-express-api-key-value" },
    {
      clientFactory(value) {
        options = value;
        return { models: { generateContent: async () => ({ text: "{}" }) } };
      },
    },
  );
  assert.equal(options.vertexai, true);
  assert.equal(options.apiKey, "test-vertex-express-api-key-value");
  assert.equal(Object.hasOwn(options, "project"), false);
  assert.equal(Object.hasOwn(options, "location"), false);
  assert.equal(Object.hasOwn(options, "httpOptions"), false);
});

test("Gemini Developer mode omits every Vertex option", () => {
  let options;
  createGoogleMealModel(
    { ...config, geminiApiKey: "test-gemini-developer-api-key-value" },
    {
      clientFactory(value) {
        options = value;
        return { models: { generateContent: async () => ({ text: "{}" }) } };
      },
    },
  );
  assert.equal(options.apiKey, "test-gemini-developer-api-key-value");
  assert.equal(Object.hasOwn(options, "vertexai"), false);
  assert.equal(Object.hasOwn(options, "project"), false);
  assert.equal(Object.hasOwn(options, "location"), false);
});
