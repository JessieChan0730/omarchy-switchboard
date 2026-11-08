import type { Geometry, Size } from "../types/Models";

/** Fit logical coordinates into a card without changing the aspect ratio. */
export function fitGeometry(
  window: Geometry,
  viewport: Geometry,
  card: Size,
): Geometry | null {
  const values = [
    window.x, window.y, window.width, window.height,
    viewport.x, viewport.y, viewport.width, viewport.height,
    card.width, card.height,
  ];
  if (!values.every(Number.isFinite)
    || window.width <= 0 || window.height <= 0
    || viewport.width <= 0 || viewport.height <= 0
    || card.width <= 0 || card.height <= 0) return null;

  const scale = Math.min(card.width / viewport.width, card.height / viewport.height);
  const offsetX = (card.width - viewport.width * scale) / 2;
  const offsetY = (card.height - viewport.height * scale) / 2;
  return {
    x: offsetX + (window.x - viewport.x) * scale,
    y: offsetY + (window.y - viewport.y) * scale,
    width: window.width * scale,
    height: window.height * scale,
  };
}

// P0/P2: normalize compositor geometry, apply clipping and verify output rotation.
