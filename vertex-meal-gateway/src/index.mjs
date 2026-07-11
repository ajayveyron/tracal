import { loadConfig } from "./config.mjs";
import { createMockMealModel } from "./mock-model.mjs";
import { createGatewayServer } from "./server.mjs";
import { createMealAnalysisService } from "./service.mjs";
import { createGoogleMealModel } from "./vertex-client.mjs";

try {
  const config = loadConfig();
  const model = config.mockModel
    ? createMockMealModel(config)
    : createGoogleMealModel(config);
  const service = createMealAnalysisService({ model, config });
  const server = createGatewayServer({ service, config });

  server.listen(config.port, config.host, () => {
    console.log(
      JSON.stringify({
        event: "gateway_started",
        host: config.host,
        port: config.port,
        model: config.model,
        provider: config.inferenceProvider,
      }),
    );
  });

  const stop = () => server.close(() => process.exit(0));
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
} catch (error) {
  console.error(
    JSON.stringify({
      event: "gateway_start_failed",
      errorType: error?.name || "Error",
      message: error?.message || "unknown",
    }),
  );
  process.exitCode = 1;
}
