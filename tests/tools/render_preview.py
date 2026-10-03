"""Renders top-down previews of the baked world from build/preview.json.

    lune run tests/tools/export_preview.luau
    python tests/tools/render_preview.py          (needs matplotlib + numpy)

Parts are drawn as their projected footprints, painter-sorted by top height. Terrain (not in the
export) is approximated from the same layout constants: ground, lane-fan grass and the creek.
"""
import json
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.patches import Polygon, Wedge

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "build", "preview.json")
OUT = os.path.join(ROOT, "docs", "images")

LIP_RADIUS = 1300
BOARD_RADIUS = 300
FAN_HALF = 3 * 8 + 4

RARITY_COLORS = {
    "Common": "#bebec4",
    "Uncommon": "#56d25c",
    "Rare": "#2e92ff",
    "Epic": "#b04cff",
    "Legendary": "#ffc428",
    "Mythic": "#ff488c",
    "Secret": "#7a34ff",
}


def hull(points):
    points = sorted(set(points))
    if len(points) <= 2:
        return points

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def footprint(part):
    px, py, pz = part["p"]
    r, u, l = part["r"], part["u"], part["l"]
    sx, sy, sz = (s / 2 for s in part["s"])
    corners = []
    top = -1e9
    for a in (-1, 1):
        for b in (-1, 1):
            for c in (-1, 1):
                x = px + r[0] * sx * a + u[0] * sy * b - l[0] * sz * c
                y = py + r[1] * sx * a + u[1] * sy * b - l[1] * sz * c
                z = pz + r[2] * sx * a + u[2] * sy * b - l[2] * sz * c
                corners.append((round(x, 2), round(z, 2)))
                top = max(top, y)
    shape = part.get("sh", "")
    if "Ball" in shape:
        radius = part["s"][0] / 2
        corners = [(px + radius * math.cos(t), pz + radius * math.sin(t)) for t in [i * math.pi / 8 for i in range(16)]]
        top = py + radius
    return hull(corners), top


def shade(rgb, top):
    factor = 0.82 + min(max(top, 0), 160) / 160 * 0.25
    return tuple(min(1.0, c / 255 * factor) for c in rgb)


def draw_terrain(ax):
    ax.set_facecolor("#6ea054")
    ax.add_patch(Polygon([(-3400, 1800), (3400, 1800), (3400, -4600), (-3400, -4600)], closed=True, color="#6aba46", zorder=0))
    # Leafy grass lane fan (angles measured from -Z toward -X)
    # Forward (-Z) is the -y direction in data coordinates, i.e. 270 degrees.
    ax.add_patch(Wedge((0, 0), LIP_RADIUS + 40, 270 - FAN_HALF, 270 + FAN_HALF, width=LIP_RADIUS - BOARD_RADIUS + 60, color="#5caa3e", zorder=0.5))
    # Creek (500 studs past the launch line)
    ax.add_patch(Wedge((0, 0), LIP_RADIUS + 500 + 32, 270 - 55, 270 + 55, width=64, color="#ecce8c", zorder=0.55))
    ax.add_patch(Wedge((0, 0), LIP_RADIUS + 500 + 22, 270 - 55, 270 + 55, width=44, color="#46aae6", zorder=0.6))


def render(parts, extent, filename, title, dpi=110, min_size=0.0):
    xmin, xmax, zmin, zmax = extent
    width = 11
    height = width * (zmax - zmin) / (xmax - xmin)
    fig, ax = plt.subplots(figsize=(width, height))
    draw_terrain(ax)
    polys, colors, tops = [], [], []
    for part in parts:
        x, _, z = part["p"]
        reach = max(part["s"]) + 50
        if x < xmin - reach or x > xmax + reach or z < zmin - reach or z > zmax + reach:
            continue
        if max(part["s"][0], part["s"][2]) < min_size:
            continue
        poly, top = footprint(part)
        if len(poly) < 3:
            continue
        polys.append(poly)
        colors.append(shade(part["c"], top))
        tops.append(top)
    order = sorted(range(len(polys)), key=lambda i: tops[i])
    collection = PolyCollection([polys[i] for i in order], facecolors=[colors[i] for i in order], edgecolors="none", zorder=2)
    ax.add_collection(collection)
    ax.set_xlim(xmin, xmax)
    # Roblox forward is -Z; flip so the launch direction points up the image.
    ax.set_ylim(zmax, zmin)
    ax.set_aspect("equal")
    ax.set_title(title, fontsize=13)
    ax.set_xlabel("X (studs)")
    ax.set_ylabel("Z (studs, forward = up)")
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, filename), dpi=dpi)
    plt.close(fig)
    print("wrote", filename, len(polys), "parts")


def render_profiles(profiles):
    fig, ax = plt.subplots(figsize=(11, 4.2))
    for lane, offset in (("Lane3", 0), ("Lane5", 0), ("Lane2", 0)):
        data = profiles.get(lane)
        if not data:
            continue
        xs = [s[0] for s in data["Samples"]]
        ys = [s[1] for s in data["Samples"]]
        cs = [RARITY_COLORS.get(s[2], "#ffffff") for s in data["Samples"]]
        ax.scatter(xs, ys, c=cs, s=9, label=f"{lane}: {data['Count']} pieces")
    ax.axvline(LIP_RADIUS, color="#444", linestyle="--", linewidth=1)
    ax.text(LIP_RADIUS - 8, 5, "launch lip", ha="right", fontsize=9)
    ax.axvline(345, color="#888", linestyle=":", linewidth=1)
    ax.text(352, 200, "hub-side growth limit", fontsize=9)
    ax.set_xlabel("distance from lane focus (studs) - ramps grow backward toward the hub")
    ax.set_ylabel("height (studs)")
    ax.set_title("Ramp side profiles (dots = track samples, coloured by piece rarity)")
    handles = [plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=c, markersize=7, label=n) for n, c in RARITY_COLORS.items()]
    ax.legend(handles=handles, loc="upper right", fontsize=8, ncol=4)
    ax.invert_xaxis()
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "ramp_profiles.png"), dpi=110)
    plt.close(fig)
    print("wrote ramp_profiles.png")


def main():
    with open(DATA) as f:
        data = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    parts = data["Parts"]
    render(parts, (-760, 760, -1400, 120), "hub_and_lanes.png", "Hub and ramp lanes (top-down, launch direction up)", dpi=120)
    render(parts, (-3600, 3600, -4600, 600), "launch_landscape.png", "Launch landscape: creek 500, road 1,000, town 2,500", dpi=100, min_size=3)
    render(parts, (-8000, 8000, -14000, 1500), "world_overview.png", "World overview: canyon 5,000 and mountains 10,000", dpi=80, min_size=20)
    render_profiles(data["Profiles"])


if __name__ == "__main__":
    main()
