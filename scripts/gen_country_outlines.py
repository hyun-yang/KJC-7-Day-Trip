#!/usr/bin/env python3
"""Generate KJC country outlines from Natural Earth 50m GeoJSON.

Usage: python3 scripts/gen_country_outlines.py
Output: lib/ui/map/country_outlines_data.dart
"""

import json
import hashlib
import math
import os
import subprocess
import time
import urllib.error
import urllib.request


REVISION = "ca96624a56bd078437bca8184e78163e5039ad19"
EXPECTED_SHA256 = "3e458fc036ad0a66411f2c1e6cac49c5d7bfb81cb1123bc513b22511a2b7fdeb"
URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    f"{REVISION}/geojson/ne_50m_admin_0_countries.geojson"
)
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".ne_50m_countries.geojson")
OUT = os.path.join(HERE, "..", "lib", "ui", "map", "country_outlines_data.dart")

# ADM0_A3: Dart suffix, simplification tolerance, minimum relative ring area,
# maximum retained rings.
COUNTRIES = {
    "KOR": ("Korea", 0.02, 0.010, 4),
    "JPN": ("Japan", 0.05, 0.030, 4),
    "CHN": ("China", 0.15, 0.003, 3),
}


def verify_payload(payload):
    actual = hashlib.sha256(payload).hexdigest()
    if actual != EXPECTED_SHA256:
        raise ValueError(
            f"Natural Earth SHA-256 mismatch: expected {EXPECTED_SHA256}, got {actual}"
        )


def download_geojson():
    """Download verified bytes into the cache, retrying at most three times."""
    temporary = CACHE + ".tmp"
    for attempt in range(1, 4):
        try:
            print(f"Natural Earth download attempt {attempt}/3 ...")
            with urllib.request.urlopen(URL, timeout=30) as response:
                payload = response.read()
            verify_payload(payload)
            with open(temporary, "wb") as target:
                target.write(payload)
            os.replace(temporary, CACHE)
            return payload
        except (OSError, ValueError, urllib.error.URLError) as error:
            if os.path.exists(temporary):
                os.remove(temporary)
            if attempt == 3:
                raise RuntimeError(
                    "unable to download Natural Earth data after 3 attempts"
                ) from error
            time.sleep(attempt)


def load_geojson():
    payload = None
    if os.path.exists(CACHE):
        with open(CACHE, "rb") as source:
            cached_payload = source.read()
        try:
            verify_payload(cached_payload)
            payload = cached_payload
            print(f"using verified Natural Earth cache: {os.path.relpath(CACHE, HERE)}")
        except ValueError as error:
            print(f"discarding invalid Natural Earth cache: {error}")
            os.remove(CACHE)
    if payload is None:
        payload = download_geojson()
    return json.loads(payload)


def outer_rings(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    if geometry["type"] == "MultiPolygon":
        return [polygon[0] for polygon in geometry["coordinates"]]
    return []


def ring_area(ring):
    """Return approximate ring area in square degrees for relative ranking."""
    return abs(
        sum(
            x1 * y2 - x2 * y1
            for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1])
        )
    ) / 2


def dp_simplify(points, tolerance):
    """Iterative Douglas-Peucker simplification for an open line."""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        low, high = stack.pop()
        if high <= low + 1:
            continue
        (x1, y1), (x2, y2) = points[low], points[high]
        dx, dy = x2 - x1, y2 - y1
        norm = math.hypot(dx, dy) or 1e-12
        best_distance, best_index = -1.0, -1
        for index in range(low + 1, high):
            px, py = points[index]
            distance = abs(dx * (y1 - py) - dy * (x1 - px)) / norm
            if distance > best_distance:
                best_distance, best_index = distance, index
        if best_distance > tolerance:
            keep[best_index] = True
            stack.extend(((low, best_index), (best_index, high)))
    return [point for point, retained in zip(points, keep) if retained]


def simplify_ring(ring, tolerance):
    """Simplify a closed ring without collapsing its identical endpoints."""
    points = ring[:-1] if ring[0] == ring[-1] else ring[:]
    if len(points) < 4:
        return ring
    start_x, start_y = points[0]
    split = max(
        range(1, len(points)),
        key=lambda index: math.hypot(
            points[index][0] - start_x, points[index][1] - start_y
        ),
    )
    first_arc = dp_simplify(points[: split + 1], tolerance)
    second_arc = dp_simplify(points[split:] + [points[0]], tolerance)
    simplified = first_arc[:-1] + second_arc[:-1]
    return simplified + [simplified[0]]


def select_geometry(data):
    selected = {}
    for feature in data["features"]:
        country_code = feature["properties"].get("ADM0_A3")
        if country_code in COUNTRIES:
            selected[country_code] = feature["geometry"]
    missing = set(COUNTRIES) - set(selected)
    if missing:
        raise ValueError(f"countries missing from Natural Earth data: {sorted(missing)}")
    return selected


def generate_country(country_code, geometry):
    name, tolerance, minimum_ratio, maximum_rings = COUNTRIES[country_code]
    rings = sorted(outer_rings(geometry), key=ring_area, reverse=True)
    biggest_area = ring_area(rings[0])
    rings = [
        ring for ring in rings if ring_area(ring) >= biggest_area * minimum_ratio
    ][:maximum_rings]
    rings = [simplify_ring(ring, tolerance) for ring in rings]
    rings = [ring for ring in rings if len(ring) >= 4]
    if not rings:
        raise ValueError(f"no usable rings generated for {country_code}")

    longitudes = [x for ring in rings for x, _ in ring]
    latitudes = [y for ring in rings for _, y in ring]
    longitude_padding = (max(longitudes) - min(longitudes)) * 0.03
    latitude_padding = (max(latitudes) - min(latitudes)) * 0.03
    west, east = min(longitudes) - longitude_padding, max(longitudes) + longitude_padding
    south, north = min(latitudes) - latitude_padding, max(latitudes) + latitude_padding
    middle_latitude = math.radians((north + south) / 2)
    aspect = ((east - west) * math.cos(middle_latitude)) / (north - south)

    lines = [
        f"const k{name}Outline = CountryOutline(",
        f"  aspect: {aspect:.4f},",
        f"  latNorth: {north:.4f}, latSouth: {south:.4f},",
        f"  lngWest: {west:.4f}, lngEast: {east:.4f},",
        "  polygons: [",
    ]
    for ring in rings:
        points = ", ".join(
            "Offset({:.4f}, {:.4f})".format(
                (longitude - west) / (east - west),
                (north - latitude) / (north - south),
            )
            for longitude, latitude in ring
        )
        lines.append(f"    [{points}],")
    lines.extend(("  ],", ");", ""))
    point_count = sum(len(ring) for ring in rings)
    print(
        f"{country_code}: rings={len(rings)} points={point_count} aspect={aspect:.3f}"
    )
    return lines


def main():
    selected = select_geometry(load_geojson())
    lines = [
        "// GENERATED by scripts/gen_country_outlines.py. Do not edit by hand.",
        "// Source: Natural Earth 50m admin_0_countries (public domain).",
        "import 'dart:ui';",
        "",
        "import '../../domain/entities/country.dart';",
        "import 'country_outline.dart';",
        "",
    ]
    for country_code in COUNTRIES:
        lines.extend(generate_country(country_code, selected[country_code]))
    lines.extend(
        (
            "final kOutlineByCountry = <Country, CountryOutline>{",
            "  Country.korea: kKoreaOutline,",
            "  Country.japan: kJapanOutline,",
            "  Country.china: kChinaOutline,",
            "};",
        )
    )
    with open(OUT, "w", encoding="utf-8") as target:
        target.write("\n".join(lines) + "\n")
    try:
        formatted = subprocess.run(
            ["dart", "format", OUT],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise RuntimeError("cannot format generated output: dart executable not found") from error
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or "unknown dart format error").strip()
        raise RuntimeError(f"cannot format generated output: {detail}") from error
    if formatted.stdout.strip():
        print(formatted.stdout.strip())
    print(f"wrote {os.path.relpath(OUT, os.path.join(HERE, '..'))}")


if __name__ == "__main__":
    main()
