/** Wrap an existing candidate index. Empty lists have no selection. */
export function wrapIndex(index: number, delta: number, count: number): number {
  if (!Number.isInteger(count) || count < 0) {
    throw new RangeError("Candidate count must be a non-negative integer");
  }
  if (count === 0) return -1;
  if (!Number.isInteger(index) || !Number.isInteger(delta)) {
    throw new RangeError("Candidate index and step must be integers");
  }
  return ((index + delta) % count + count) % count;
}

// P1/P2: add scope filtering, MRU ordering, empty slots and queue generation.
