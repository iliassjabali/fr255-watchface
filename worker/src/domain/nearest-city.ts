export type City = {
  readonly id: number;
  readonly lat: number;
  readonly lon: number;
};

/** Beyond this distance the watch computes the times itself. */
export const MAX_CITY_DISTANCE_KM = 25;

const EARTH_RADIUS_KM = 6371;
const toRadians = (degrees: number): number => (degrees * Math.PI) / 180;

/** Great-circle distance in kilometres (haversine). */
function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(a)));
}

type Nearest = { readonly city: City; readonly distance: number };

function findNearest(cities: readonly City[], lat: number, lon: number): Nearest | undefined {
  let best: Nearest | undefined;
  for (const city of cities) {
    const distance = distanceKm(lat, lon, city.lat, city.lon);
    if (!best || distance < best.distance) best = { city, distance };
  }
  return best;
}

export function nearestCity(cities: readonly City[], lat: number, lon: number): City | undefined {
  return findNearest(cities, lat, lon)?.city;
}

/** The nearest city, or undefined when it is farther than MAX_CITY_DISTANCE_KM. */
export function nearestCityWithinLimit(
  cities: readonly City[],
  lat: number,
  lon: number,
): City | undefined {
  const nearest = findNearest(cities, lat, lon);
  return nearest && nearest.distance <= MAX_CITY_DISTANCE_KM ? nearest.city : undefined;
}
