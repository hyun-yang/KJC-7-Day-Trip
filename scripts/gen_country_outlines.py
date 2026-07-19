#!/usr/bin/env python3
"""Generate KJC map data and the flag-map Travel SVG from Natural Earth.

Usage: python3 scripts/gen_country_outlines.py
Outputs:
  lib/ui/map/country_outlines_data.dart
  assets/illustrations/journey_line_splash.svg
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
SVG_OUT = os.path.join(
    HERE, "..", "assets", "illustrations", "journey_line_splash.svg"
)

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


def prepare_country(country_code, geometry):
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
    normalized_rings = [
        [
            (
                (longitude - west) / (east - west),
                (north - latitude) / (north - south),
            )
            for longitude, latitude in ring
        ]
        for ring in rings
    ]
    return name, aspect, north, south, west, east, normalized_rings


def generate_country(country_code, geometry):
    name, aspect, north, south, west, east, rings = prepare_country(
        country_code, geometry
    )

    lines = [
        f"const k{name}Outline = CountryOutline(",
        f"  aspect: {aspect:.4f},",
        f"  latNorth: {north:.4f}, latSouth: {south:.4f},",
        f"  lngWest: {west:.4f}, lngEast: {east:.4f},",
        "  polygons: [",
    ]
    for ring in rings:
        points = ", ".join(
            "Offset({:.4f}, {:.4f})".format(x, y) for x, y in ring
        )
        lines.append(f"    [{points}],")
    lines.extend(("  ],", ");", ""))
    point_count = sum(len(ring) for ring in rings)
    print(
        f"{country_code}: rings={len(rings)} points={point_count} aspect={aspect:.3f}"
    )
    return lines


def svg_path(ring, x, y, width, height):
    points = [
        (x + normalized_x * width, y + normalized_y * height)
        for normalized_x, normalized_y in ring
    ]
    commands = [f"M{points[0][0]:.2f} {points[0][1]:.2f}"]
    commands.extend(f"L{point_x:.2f} {point_y:.2f}" for point_x, point_y in points[1:])
    commands.append("Z")
    return "".join(commands)


def star_points(
    center_x, center_y, outer_radius, inner_radius, rotation_degrees=-90
):
    points = []
    for index in range(10):
        angle = math.radians(rotation_degrees + index * 36)
        radius = outer_radius if index % 2 == 0 else inner_radius
        points.append(
            f"{center_x + math.cos(angle) * radius:.2f},"
            f"{center_y + math.sin(angle) * radius:.2f}"
        )
    return " ".join(points)


def points_toward(source_x, source_y, target_x, target_y):
    return math.degrees(math.atan2(target_y - source_y, target_x - source_x))


def generate_flag_map_svg(selected):
    placements = {
        "KOR": (8, 65, 77, 150, "korea"),
        "JPN": (94, 72, 119, 135, "japan"),
        "CHN": (222, 84, 157, 112, "china"),
    }
    prepared = {
        code: prepare_country(code, selected[code]) for code in COUNTRIES
    }
    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 390 280" fill="none">',
        '  <rect width="390" height="280" rx="30" fill="#F8F5EF"/>',
        "  <defs>",
    ]
    shape_paths = {}
    for code in COUNTRIES:
        x, y, width, height, slug = placements[code]
        rings = prepared[code][-1]
        paths = [svg_path(ring, x, y, width, height) for ring in rings]
        shape_paths[slug] = paths
        lines.append(f'    <clipPath id="{slug}-map">')
        for index, path in enumerate(paths):
            lines.append(
                f'      <path id="{slug}-shape-{index + 1}" d="{path}"/>'
            )
        lines.append("    </clipPath>")
    lines.extend(("  </defs>",))

    lines.extend(
        (
            '  <g id="korea-flag" clip-path="url(#korea-map)">',
            '    <rect x="8" y="65" width="77" height="150" fill="#FFFFFF"/>',
            '    <path id="korea-taegeuk-red" fill="#CD2E3A" d="M30.5 140a16 16 0 0 1 32 0 8 8 0 0 0-16 0 8 8 0 0 1-16 0Z"/>',
            '    <path id="korea-taegeuk-blue" fill="#0047A0" d="M62.5 140a16 16 0 0 1-32 0 8 8 0 0 0 16 0 8 8 0 0 1 16 0Z"/>',
            '    <g id="korea-trigrams" stroke="#111111" stroke-width="2" stroke-linecap="square">',
            '      <g id="korea-geon" data-pattern="111" transform="translate(26 111) rotate(-32)">',
            '        <path d="M-7-5H7M-7 0H7M-7 5H7"/>',
            "      </g>",
            '      <g id="korea-gon" data-pattern="000" transform="translate(65 170) rotate(-32)">',
            '        <path d="M-7-5h5m4 0h5M-7 0h5m4 0h5M-7 5h5m4 0h5"/>',
            "      </g>",
            '      <g id="korea-gam" data-pattern="010" transform="translate(65 111) rotate(35)">',
            '        <path d="M-7-5h5m4 0h5M-7 0H7M-7 5h5m4 0h5"/>',
            "      </g>",
            '      <g id="korea-ri" data-pattern="101" transform="translate(27 170) rotate(35)">',
            '        <path d="M-7-5H7M-7 0h5m4 0h5M-7 5H7"/>',
            "      </g>",
            "    </g>",
            "  </g>",
            '  <g id="japan-flag" clip-path="url(#japan-map)">',
            '    <rect x="94" y="72" width="119" height="135" fill="#FFFFFF"/>',
            '    <circle id="japan-sun" cx="153.5" cy="139.5" r="22" fill="#BC002D"/>',
            "  </g>",
            '  <g id="china-flag" clip-path="url(#china-map)">',
            '    <rect x="222" y="84" width="157" height="112" fill="#DE2910"/>',
            '    <g id="china-stars" fill="#FFDE00">',
            f'      <polygon id="china-star-main" points="{star_points(263, 122, 13, 5.2)}"/>',
            f'      <polygon id="china-star-1" data-points-to="#china-star-main" points="{star_points(283, 124, 5, 2, points_toward(283, 124, 263, 122))}"/>',
            f'      <polygon id="china-star-2" data-points-to="#china-star-main" points="{star_points(296, 128, 5, 2, points_toward(296, 128, 263, 122))}"/>',
            f'      <polygon id="china-star-3" data-points-to="#china-star-main" points="{star_points(291, 141, 5, 2, points_toward(291, 141, 263, 122))}"/>',
            f'      <polygon id="china-star-4" data-points-to="#china-star-main" points="{star_points(279, 146, 5, 2, points_toward(279, 146, 263, 122))}"/>',
            "    </g>",
            "  </g>",
        )
    )
    for slug in ("korea", "japan", "china"):
        lines.append(
            f'  <g id="{slug}-outline" fill="none" stroke="#153C33" '
            'stroke-width="1.8" stroke-linejoin="round">'
        )
        for index in range(len(shape_paths[slug])):
            lines.append(f'    <use href="#{slug}-shape-{index + 1}"/>')
        lines.append("  </g>")
    lines.extend(("</svg>", ""))
    return "\n".join(lines)


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
    with open(SVG_OUT, "w", encoding="utf-8") as target:
        target.write(generate_flag_map_svg(selected))
    print(f"wrote {os.path.relpath(SVG_OUT, os.path.join(HERE, '..'))}")


if __name__ == "__main__":
    main()
