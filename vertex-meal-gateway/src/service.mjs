import {
  GatewayError,
  makeAnalyzedMealDraft,
  parseAnalyzeRequest,
} from "./contracts.mjs";
import { ModelResponseError } from "./vertex-client.mjs";

export function createMealAnalysisService({ model, config }) {
  if (!model || typeof model.generate !== "function") {
    throw new TypeError("model.generate is required");
  }

  return Object.freeze({
    async analyze(payload) {
      const input = parseAnalyzeRequest(payload, config);
      const controller = new AbortController();
      let timer;
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(
            new GatewayError(
              504,
              "analysis_timeout",
              "Meal analysis took too long.",
            ),
          );
        }, config.modelTimeoutMs);
        timer.unref?.();
      });

      try {
        const modelValue = await Promise.race([
          model.generate(input, { signal: controller.signal }),
          timeout,
        ]);
        return makeAnalyzedMealDraft(modelValue, input, config.model);
      } catch (error) {
        if (error instanceof GatewayError && error.code === "analysis_timeout") {
          throw error;
        }
        if (controller.signal.aborted || error?.name === "AbortError") {
          throw new GatewayError(
            504,
            "analysis_timeout",
            "Meal analysis took too long.",
          );
        }
        if (error instanceof ModelResponseError) {
          throw new GatewayError(
            502,
            "invalid_model_response",
            "The inference provider returned an unusable meal estimate.",
          );
        }
        throw error;
      } finally {
        clearTimeout(timer);
      }
    },
  });
}
