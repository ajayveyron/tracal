import { createHash, randomBytes } from "node:crypto";

const token = randomBytes(32).toString("base64url");
const digest = createHash("sha256").update(token, "utf8").digest("hex");

process.stdout.write(
  [
    "Raw device token (shown once; pair it into the iPhone Keychain):",
    token,
    "",
    "TRACAL_DEVICE_TOKEN_SHA256 (configure only this value on the gateway):",
    digest,
    "",
    "This command did not write either value to disk.",
    "",
  ].join("\n"),
);
