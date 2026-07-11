#!/usr/bin/env node

import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const root = "/Users/ajaypawriya/Desktop/Projects/tracal";
const envFile = "/Users/ajaypawriya/Desktop/Projects/geo-repair/.env";
const promptsFile = path.join(root, "design/tracal-app-icon-prompts.json");
const styleImage = "/tmp/tracal-vertex-first.png";
const runDirectory = path.join(
  "/Users/ajaypawriya/Desktop/Vertex Media Exports",
  `${new Date().toISOString().slice(0, 10)}-tracal-app-icon-variations`,
);

const negative = [
  "words",
  "letters",
  "numerals",
  "brand marks",
  "Apple logo",
  "medical cross",
  "health cross",
  "bathroom scale",
  "weighing scale",
  "photorealistic food",
  "human figure",
  "hands",
  "phone mockup",
  "screenshot",
  "interface controls",
  "tiny detail",
  "thin lines",
  "transparent background",
  "rounded-square border",
  "baked-in corner radius",
  "neon",
  "rainbow palette",
  "excessive gloss",
  "shadow outside the canvas",
].join(", ");

function readEnv(file) {
  const values = {};
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[match[1]] = value;
  }
  return values;
}

function outputImage(response) {
  const parts = response?.candidates?.[0]?.content?.parts ?? [];
  const image = parts.find((part) => part.inlineData?.data);
  if (image?.inlineData?.data) return image.inlineData.data;
  const explanation = parts.find((part) => part.text)?.text;
  throw new Error(explanation ? "Model returned text instead of an image." : "No image returned.");
}

async function runWithLimit(items, limit, operation) {
  let next = 0;
  const results = new Array(items.length);
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (next < items.length) {
        const index = next++;
        try {
          results[index] = { ok: true, value: await operation(items[index], index) };
        } catch (error) {
          results[index] = {
            ok: false,
            error: error instanceof Error ? error.message : "Unknown generation error",
          };
        }
      }
    }),
  );
  return results;
}

const env = readEnv(envFile);
if (!env.GEMINI_API_KEY) throw new Error("Geo Repair GEMINI_API_KEY is missing.");
if (!fs.existsSync(styleImage)) throw new Error("Tracal style reference is missing.");

const require = createRequire(
  "/Users/ajaypawriya/Desktop/Projects/tracal/vertex-meal-gateway/package.json",
);
const { GoogleGenAI } = await import(require.resolve("@google/genai"));
const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
const prompts = JSON.parse(fs.readFileSync(promptsFile, "utf8"));
const styleData = fs.readFileSync(styleImage).toString("base64");

fs.mkdirSync(runDirectory, { recursive: true });
console.log(`Generating ${prompts.length} local image asset variants with Google Gemini.`);

const results = await runWithLimit(prompts, 5, async (item) => {
  const destination = path.join(runDirectory, `${item.name}.png`);
  if (fs.existsSync(destination)) {
    throw new Error(`Output already exists: ${destination}`);
  }

  const response = await ai.models.generateContent({
    model: "gemini-2.5-flash-image",
    contents: [
      {
        role: "user",
        parts: [
          {
            text:
              `${item.prompt}\n\nAvoid: ${negative}. ` +
              "No text, logos, or watermarks. Use the attached screenshot only for its cream, sage, graphite palette and restrained glass material; never reproduce interface elements.",
          },
          {
            inlineData: {
              data: styleData,
              mimeType: "image/png",
            },
          },
        ],
      },
    ],
    config: {
      responseModalities: ["TEXT", "IMAGE"],
      imageConfig: {
        aspectRatio: "1:1",
        imageSize: "1K",
      },
    },
  });

  fs.writeFileSync(destination, Buffer.from(outputImage(response), "base64"));
  console.log(`saved ${destination}`);
  return destination;
});

const failures = results
  .map((result, index) => ({ result, item: prompts[index] }))
  .filter(({ result }) => !result.ok);

for (const { result, item } of failures) {
  console.error(`failed ${item.name}: ${result.error}`);
}

if (failures.length > 0) {
  throw new Error(`${failures.length} of ${prompts.length} variants failed.`);
}
