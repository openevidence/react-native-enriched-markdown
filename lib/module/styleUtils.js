"use strict";

export function flattenSpoilerStyle(userSpoiler) {
  if (!userSpoiler) return undefined;
  const flat = {};
  if (userSpoiler.color !== undefined) flat.color = userSpoiler.color;
  if (userSpoiler.particles?.density !== undefined) flat.particleDensity = userSpoiler.particles.density;
  if (userSpoiler.particles?.speed !== undefined) flat.particleSpeed = userSpoiler.particles.speed;
  if (userSpoiler.solid?.borderRadius !== undefined) flat.solidBorderRadius = userSpoiler.solid.borderRadius;
  return Object.keys(flat).length > 0 ? flat : undefined;
}
function isSubStyleEqual(a, b) {
  const keys = Object.keys(a);
  if (keys.length !== Object.keys(b).length) return false;
  for (const key of keys) {
    const valueA = a[key];
    const valueB = b[key];
    if (valueA === valueB) continue;
    if (typeof valueA === 'object' && valueA !== null && typeof valueB === 'object' && valueB !== null) {
      const nestedKeysA = Object.keys(valueA);
      const nestedKeysB = Object.keys(valueB);
      if (nestedKeysA.length !== nestedKeysB.length) return false;
      for (const nestedKey of nestedKeysA) {
        if (valueA[nestedKey] !== valueB[nestedKey]) {
          return false;
        }
      }
      continue;
    }
    return false;
  }
  return true;
}
export function isStyleEqual(a, b, referenceKeys) {
  for (const key of referenceKeys) {
    const subA = a[key];
    const subB = b[key];
    if (subA === subB) continue;
    if (!subA || !subB) return false;
    if (!isSubStyleEqual(subA, subB)) {
      return false;
    }
  }
  return true;
}
//# sourceMappingURL=styleUtils.js.map