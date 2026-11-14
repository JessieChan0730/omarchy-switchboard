import type { Geometry, Size } from "../types/Models";

/** Move to a neighbour in the same row or column; keep selection at gaps and edges. */
export function navigateGrid(
  index: number,
  count: number,
  columns: number,
  direction: "left" | "right" | "up" | "down",
): number {
  if (count <= 0) return -1;
  if (index < 0 || index >= count || columns < 1) return index;
  const column = index % columns;
  if (direction === "left") return column > 0 ? index - 1 : index;
  if (direction === "right") return column + 1 < columns && index + 1 < count ? index + 1 : index;
  if (direction === "up") return index >= columns ? index - columns : index;
  return index + columns < count ? index + columns : index;
}

/** Keep small overviews wide; use four columns beyond the first twelve items. */
export function workspaceGrid(count: number): { rows: number; columns: number } {
  if (!Number.isFinite(count) || count <= 0) return { rows: 1, columns: 1 };
  const items = Math.max(1, Math.floor(count));
  const columns = items > 12 ? 4 : Math.ceil(items / Math.floor(Math.sqrt(items)));
  return { rows: Math.ceil(items / columns), columns };
}

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
