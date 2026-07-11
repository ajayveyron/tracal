import { ImageResponse } from "next/og";

export const socialImageSize = { width: 1200, height: 630 };

export function createSocialImage() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "stretch",
        background: "#f4f5f1",
        color: "#172019",
        fontFamily: "Arial, sans-serif",
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "68px 76px", width: "72%" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 18, fontSize: 32, fontWeight: 700 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 58, height: 58, borderRadius: 15, background: "#172019", color: "#f4f5f1", fontSize: 32 }}>T</div>
          Tracal
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ display: "flex", flexDirection: "column", fontSize: 76, lineHeight: 0.98, letterSpacing: "-4px", fontWeight: 750 }}>
            <span>Log the meal.</span>
            <span>Keep the data.</span>
          </div>
          <div style={{ marginTop: 30, color: "#566159", fontSize: 28 }}>Private calorie tracking for iPhone.</div>
        </div>
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: "28%", background: "#dde3d8" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 230, height: 230, borderRadius: 115, background: "#f4f5f1" }}>
          <div style={{ width: 146, height: 146, borderRadius: 73, background: "#b8c9b9" }} />
        </div>
      </div>
    </div>,
    socialImageSize,
  );
}
