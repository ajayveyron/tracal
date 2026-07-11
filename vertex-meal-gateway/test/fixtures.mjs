export const analysisId = "4fd883be-1727-4b88-96e1-78c2ba783573";

export const textRequest = {
  schemaVersion: 1,
  analysisId,
  source: "typedText",
  loggedAt: "2026-07-11T12:30:00Z",
  input: {
    kind: "text",
    text: "Two bananas and a protein shake with milk",
    hint: null,
    image: null,
  },
};

export const photoRequest = {
  schemaVersion: 1,
  analysisId,
  source: "cameraPhoto",
  loggedAt: "2026-07-11T12:30:00.123Z",
  input: {
    kind: "photo",
    hint: "I ate the whole bowl",
    image: {
      bytesBase64: Buffer.from("small fake jpeg").toString("base64"),
      mimeType: "image/jpeg",
      pixelWidth: 1_200,
      pixelHeight: 900,
    },
  },
};

export const modelMeal = {
  containsFoodOrDrink: true,
  title: "Bananas and protein shake",
  reviewReason: "Check the shake serving and milk amount.",
  items: [
    {
      name: "Banana",
      quantity: 2,
      unit: "medium",
      estimatedGrams: 236,
      nutrition: {
        caloriesKcal: 210,
        proteinGrams: 2.6,
        carbohydrateGrams: 54,
        fatGrams: 0.8,
      },
      identificationConfidence: 0.98,
      portionConfidence: 0.8,
      assumptions: ["Medium bananas"],
    },
    {
      name: "Protein shake with milk",
      quantity: 1,
      unit: "shake",
      estimatedGrams: 350,
      nutrition: {
        caloriesKcal: 260,
        proteinGrams: 32,
        carbohydrateGrams: 20,
        fatGrams: 6,
      },
      identificationConfidence: 0.9,
      portionConfidence: 0.65,
      assumptions: ["One scoop protein powder", "250 ml low-fat milk"],
    },
  ],
};

export const config = {
  project: "test-project",
  location: "global",
  model: "gemini-test",
  maxBodyBytes: 8 * 1024 * 1024,
  maxImageBytes: 5 * 1024 * 1024,
  modelTimeoutMs: 500,
  deviceTokenHash: null,
  allowInsecureLocal: true,
};
