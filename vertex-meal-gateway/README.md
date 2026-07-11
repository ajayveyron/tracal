# Tracal Vertex meal gateway

A small private inference service for Tracal's typed-meal and meal-photo paths.
It is plain Node ESM, has no compile step, and uses the current `@google/genai`
SDK. Vertex AI with Application Default Credentials (ADC) is the default on
Cloud Run. For personal production without GCP ops, deploy the same service to
**Vercel** with `TRACAL_GEMINI_API_KEY`. It never contains a GCP credential,
API key, or raw device token in the repository.

## Personal production (Vercel, recommended for you)

One-time on your Mac:

```sh
cd vertex-meal-gateway
npm install
npm run setup:personal
# follow printed Vercel env instructions, then:
npx vercel --prod
# after you have the URL:
npm run setup:personal -- --url https://YOUR.vercel.app --write-xcconfig
```

Set on Vercel:

- `TRACAL_DEVICE_TOKEN_SHA256` — digest from the setup script  
- `TRACAL_GEMINI_API_KEY` — from [Google AI Studio](https://aistudio.google.com/apikey)  

`Config/Local.xcconfig` (gitignored) receives the URL + **raw** token. Rebuild
the iOS app; it auto-seeds Keychain and UserDefaults. No Settings paste.

Requires a Vercel plan that allows ~60s serverless duration for photo analysis.

## Runtime contract

- `GET /healthz` returns `{ "status": "ok" }`.
- `POST /v1/analyze` accepts Tracal schema v1 and requires
  `Authorization: Bearer <per-install-token>` unless loopback-only development
  bypass was explicitly enabled.
- Responses are schema v1 drafts. The iOS client maps them into
  `AnalyzedMealDraft`, sets `analysisRoute` to `vertexFallback`, validates and
  recomputes totals, then saves the meal directly to Today.
- Structured model output includes `containsFoodOrDrink`. A false value returns
  HTTP `422` with code `no_food_detected`; the app keeps the composer and photo
  open and does not create a meal.

Typed request:

```json
{
  "schemaVersion": 1,
  "analysisId": "4fd883be-1727-4b88-96e1-78c2ba783573",
  "source": "typedText",
  "loggedAt": "2026-07-11T12:30:00Z",
  "input": {
    "kind": "text",
    "text": "Two bananas and a protein shake with milk",
    "hint": null,
    "image": null
  }
}
```

Photo request:

```json
{
  "schemaVersion": 1,
  "analysisId": "4fd883be-1727-4b88-96e1-78c2ba783573",
  "source": "cameraPhoto",
  "loggedAt": "2026-07-11T12:30:00Z",
  "input": {
    "kind": "photo",
    "hint": "I ate the whole bowl",
    "image": {
      "bytesBase64": "...",
      "mimeType": "image/jpeg",
      "pixelWidth": 1536,
      "pixelHeight": 1152
    }
  }
}
```

Response:

```json
{
  "schemaVersion": 1,
  "analysisId": "4fd883be-1727-4b88-96e1-78c2ba783573",
  "title": "Bananas and protein shake",
  "items": [
    {
      "id": "582cb20f-6709-4ac0-b9c8-cbf2e1277950",
      "name": "Banana",
      "amount": 2,
      "unit": "medium",
      "estimatedGrams": 236,
      "caloriesKcal": 210,
      "proteinG": 2.6,
      "carbohydrateG": 54,
      "fatG": 0.8,
      "identificationConfidence": 0.98,
      "portionConfidence": 0.8,
      "assumptions": ["Medium bananas"]
    }
  ],
  "needsReview": true,
  "reviewReason": "Shake serving and milk amount are estimated.",
  "promptVersion": "tracal-meal-v1",
  "modelVersion": "gemini-3-flash-preview"
}
```

## One-time device pairing

Generate a high-entropy token and its digest without writing either to disk:

```sh
npm run token
```

The command shows two values:

1. Copy the raw token once into Tracal's secure pairing flow. The app stores it
   only in the iOS Keychain, protected by the app's local Face ID/device-passcode
   lock. Do not add it to Swift source, `Info.plist`, `UserDefaults`, shell startup
   files, or Cloud Run configuration.
2. Configure only the displayed SHA-256 digest as
   `TRACAL_DEVICE_TOKEN_SHA256` on the gateway.
3. Discard the raw token from the clipboard after pairing. The gateway hashes
   each presented bearer token and performs a constant-time digest comparison.

The service never logs the authorization header, meal description, image data,
model response, or raw upstream error.

## Inference provider modes

Provider selection is explicit. There is no cross-provider fallback:

| Mode | Configuration | SDK client |
| --- | --- | --- |
| Vertex AI with ADC, default | No provider key | `{ vertexai: true, project, location }` |
| Vertex AI Express | `TRACAL_VERTEX_API_KEY` | `{ vertexai: true, apiKey }` |
| Gemini Developer API | `TRACAL_GEMINI_API_KEY` | `{ apiKey }` with no Vertex option |

The two API-key variables are mutually exclusive. Both are gateway-only secrets
and are never sent to the app or written to logs. Gemini Developer API mode is
provided for an explicitly authorized private/local environment; it is not
described as Vertex and does not change the ADC production default.

## Local development with ADC

Prerequisites are Node 20+, a GCP project with Vertex AI enabled, and local ADC:

```sh
gcloud auth application-default login
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="global"
npm install
```

For an authenticated local run, configure the token digest from the pairing
step and start the service:

```sh
export TRACAL_DEVICE_TOKEN_SHA256="the-64-character-digest"
npm start
```

The default bind address is `127.0.0.1:8080`. A no-token bypass must be explicit,
works only outside production, and refuses to bind a non-loopback interface:

```sh
export TRACAL_ALLOW_INSECURE_LOCAL=true
npm start
```

## Cloud Run configuration

The included Dockerfile runs as a non-root user. Cloud Run supplies ADC through
the service identity; grant that identity the minimum Vertex AI User role needed
to call Gemini. Required configuration:

```text
GOOGLE_CLOUD_PROJECT=<project id>
GOOGLE_CLOUD_LOCATION=global
TRACAL_DEVICE_TOKEN_SHA256=<paired token digest>
```

`K_SERVICE` makes the container bind `0.0.0.0` automatically, while `PORT` is
read from Cloud Run. `TRACAL_MODEL` can override the default
`gemini-3-flash-preview` without a code change (`VERTEX_MODEL` remains a legacy
alias).

For the no-account iPhone flow, Cloud Run must permit network invocation and the
gateway's per-install bearer check is the application authentication boundary.
If Cloud Run IAM is kept private instead, the caller also needs a Google-signed
ID token; the per-install Tracal token does not replace Cloud Run IAM.

## Guardrails

- Maximum JSON request: 8 MiB, configurable up to 12 MiB.
- Maximum decoded image: 5 MiB, configurable up to 8 MiB.
- Accepted images: JPEG, PNG, WebP; dimensions and pixel count are validated.
- Maximum typed description: 4,000 characters; maximum hint: 500 characters.
- Vertex timeout: 25 seconds, configurable from 1 through 55 seconds.
- Provider output uses `application/json` plus JSON Schema and is validated again
  before returning. Nutrition and confidence bounds are enforced server-side.
- Gemini 3 structured extraction uses minimal thinking and an 8,192-token output
  budget. The one bounded second attempt uses a compact 12,288-token request for
  truncated JSON or a retryable upstream failure; other client errors and aborts
  are not retried. Repeated pieces are grouped to keep photo drafts bounded.
- Uncertainty notes are bounded to 500 characters. Nutrition, confidence, item
  count, payload, and response-size limits remain independently enforced.
- Results retain `needsReview` and `reviewReason` as uncertainty metadata for
  compatibility; they do not trigger a review screen.
- No request content or image is persisted by this service.

Run the focused mocked suite with:

```sh
npm test
```

## Official references

- [Google Gen AI SDK on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/sdks/overview)
- [Vertex AI Gemini quickstart for Node.js and ADC](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start/quickstart)
- [`@google/genai` structured-output configuration](https://googleapis.github.io/js-genai/release_docs/interfaces/types.GenerateContentConfig.html)
- [`@google/genai` multimodal `inlineData` part](https://googleapis.github.io/js-genai/release_docs/interfaces/types.Part.html)
- [Cloud Run authentication overview](https://docs.cloud.google.com/run/docs/authenticating/overview)
