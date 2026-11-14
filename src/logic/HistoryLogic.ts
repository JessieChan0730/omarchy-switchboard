/** Pure MRU bookkeeping. Call only after a verified real focus event. */
export function recordFocus(
  history: readonly string[],
  key: string,
  limit = 64,
): readonly string[] {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new RangeError("History limit must be a positive integer");
  }
  if (key.length === 0) return history.slice();
  return [key, ...history.filter((entry) => entry !== key)].slice(0, limit);
}
