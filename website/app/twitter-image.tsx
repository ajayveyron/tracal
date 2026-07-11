import { createSocialImage, socialImageSize } from "@/lib/social-image";

export const alt = "Tracal — Log the meal. Keep the data.";
export const size = socialImageSize;
export const contentType = "image/png";

export default function TwitterImage() {
  return createSocialImage();
}
