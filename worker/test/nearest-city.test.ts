import { describe, expect, it } from "vitest";
import {
  MAX_CITY_DISTANCE_KM,
  nearestCity,
  nearestCityWithinLimit,
  type City,
} from "../src/domain/nearest-city.js";

const cities: readonly City[] = [
  { id: 1, lat: 34.0209, lon: -6.8416 },
  { id: 58, lat: 33.5731, lon: -7.5898 },
  { id: 104, lat: 31.6295, lon: -7.9811 },
];

describe("nearestCity", () => {
  it("picks Casablanca for coordinates in Casablanca", () => {
    expect(nearestCity(cities, 33.57, -7.59)?.id).toBe(58);
  });

  it("picks Rabat for coordinates in Rabat", () => {
    expect(nearestCity(cities, 34.02, -6.84)?.id).toBe(1);
  });

  it("picks the closest city for a point far away", () => {
    expect(nearestCity(cities, 20, -15)?.id).toBe(104);
  });

  it("handles the antimeridian", () => {
    const wrap: readonly City[] = [
      { id: 1, lat: 0, lon: 179 },
      { id: 2, lat: 0, lon: 100 },
    ];
    expect(nearestCity(wrap, 0, -179)?.id).toBe(1);
  });

  it("returns undefined for an empty list", () => {
    expect(nearestCity([], 33, -7)).toBeUndefined();
  });
});

describe("nearestCityWithinLimit", () => {
  // One degree of latitude is about 111.2 km.
  it("uses a limit of 25 km", () => {
    expect(MAX_CITY_DISTANCE_KM).toBe(25);
  });

  it("returns the city when it is about 20 km away", () => {
    expect(nearestCityWithinLimit(cities, 33.5731 + 0.18, -7.5898)?.id).toBe(58);
  });

  it("returns undefined when the nearest city is about 26 km away", () => {
    expect(nearestCityWithinLimit(cities, 33.5731 + 0.234, -7.5898)).toBeUndefined();
  });

  it("returns undefined when the list is empty", () => {
    expect(nearestCityWithinLimit([], 33, -7)).toBeUndefined();
  });
});
