import { createHash, timingSafeEqual } from "node:crypto";

const MAX_AUTHORIZATION_LENGTH = 768;

/**
 * Verifies a per-install bearer token without retaining the raw value. The
 * configured value is only a SHA-256 digest, and both digests are compared in
 * constant time.
 */
export function isAuthorized(authorizationHeader, config) {
  if (!config.deviceTokenHash) {
    return config.allowInsecureLocal === true;
  }

  if (
    typeof authorizationHeader !== "string" ||
    authorizationHeader.length > MAX_AUTHORIZATION_LENGTH
  ) {
    return false;
  }

  const match = /^Bearer\s+([^\s]+)$/i.exec(authorizationHeader);
  if (!match || match[1].length < 32) return false;

  const actual = createHash("sha256").update(match[1], "utf8").digest();
  const expected = Buffer.from(config.deviceTokenHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
