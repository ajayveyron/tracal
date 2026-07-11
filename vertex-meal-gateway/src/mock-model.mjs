/**
 * Deterministic local model for Simulator / CI. Never enable in production.
 * Produces schema-valid meal drafts so the full iOS → gateway path is testable
 * without Vertex credentials.
 */
export function createMockMealModel(config = {}) {
  const modelVersion = config.model || "mock-meal-v1";

  return Object.freeze({
    async generate(input, { signal } = {}) {
      if (signal?.aborted) {
        const error = new Error("Aborted");
        error.name = "AbortError";
        throw error;
      }

      // parseAnalyzeRequest maps client "photo" inputs to kind "image".
      if (input.kind === "image" || input.kind === "photo") {
        const hint = (input.hint || "").trim();
        const title = hint
          ? truncate(`Meal photo: ${hint}`, 80)
          : "Meal from photo";
        return {
          containsFoodOrDrink: true,
          title,
          reviewReason: "Mock photo estimate for local testing.",
          items: [
            {
              name: hint ? truncate(hint, 60) : "Plated meal",
              quantity: 1,
              unit: "serving",
              estimatedGrams: 420,
              nutrition: {
                caloriesKcal: 640,
                proteinGrams: 28,
                carbohydrateGrams: 62,
                fatGrams: 28,
              },
              identificationConfidence: 0.72,
              portionConfidence: 0.55,
              assumptions: ["Mock model; portions are placeholders"],
            },
          ],
        };
      }

      const text = (input.text || "").trim();
      const title = deriveTitle(text);
      const items = deriveItems(text);
      return {
        containsFoodOrDrink: true,
        title,
        reviewReason: "Mock text estimate for local testing.",
        items,
        // model version is applied by makeAnalyzedMealDraft via config.model
        _mockModel: modelVersion,
      };
    },
  });
}

function deriveTitle(text) {
  if (!text) return "Meal";
  const first = text.split(/[.,\n]/)[0]?.trim() || text;
  return truncate(first.replace(/\s+/g, " "), 80);
}

function deriveItems(text) {
  const lower = text.toLowerCase();
  // Common UI-test meals
  if (lower.includes("masala dosa") || lower.includes("filter coffee")) {
    return [
      mealItem("Masala dosa", 2, "piece", 280, {
        caloriesKcal: 420,
        proteinGrams: 10,
        carbohydrateGrams: 58,
        fatGrams: 14,
      }),
      mealItem("Filter coffee with milk and sugar", 1, "cup", 180, {
        caloriesKcal: 90,
        proteinGrams: 3,
        carbohydrateGrams: 12,
        fatGrams: 3,
      }),
    ];
  }

  if (lower.includes("banana")) {
    return [
      mealItem("Banana", countHint(lower, 1), "medium", 118, {
        caloriesKcal: 105,
        proteinGrams: 1.3,
        carbohydrateGrams: 27,
        fatGrams: 0.4,
      }),
    ];
  }

  if (lower.includes("sushi")) {
    return [
      mealItem("Sushi pieces", 8, "piece", 240, {
        caloriesKcal: 480,
        proteinGrams: 22,
        carbohydrateGrams: 62,
        fatGrams: 12,
      }),
    ];
  }

  return [
    mealItem(truncate(text || "Meal item", 60), 1, "serving", 300, {
      caloriesKcal: 450,
      proteinGrams: 20,
      carbohydrateGrams: 45,
      fatGrams: 18,
    }),
  ];
}

function mealItem(name, quantity, unit, estimatedGrams, nutrition) {
  return {
    name,
    quantity,
    unit,
    estimatedGrams,
    nutrition,
    identificationConfidence: 0.9,
    portionConfidence: 0.75,
    assumptions: ["Mock model estimate"],
  };
}

function countHint(text, fallback) {
  const match = text.match(/\b(two|2|three|3|one|1)\b/);
  if (!match) return fallback;
  switch (match[1]) {
    case "two":
    case "2":
      return 2;
    case "three":
    case "3":
      return 3;
    default:
      return 1;
  }
}

function truncate(value, max) {
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1).trimEnd()}…`;
}
