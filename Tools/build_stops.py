#!/usr/bin/env python3
"""Build the bundled stop -> services catalog for the app from a BODS GTFS zip.

BODS has no "which services call at this stop" API, so we derive it offline from
the timetable (GTFS) and ship the result as a small JSON resource.

Usage:
    python3 Tools/build_stops.py path/to/gtfs_south_east.zip [output.json]

Download the regional GTFS zip once from:
    https://data.bus-data.dft.gov.uk/timetable/download/gtfs-file/south_east/

The script filters to a bounding box around Brighton & Hove, joins
stop_times -> trips -> routes, and emits, per stop, the set of services (route
short names) with their destination headsigns.
"""

import csv
import io
import json
import sys
import zipfile
from collections import defaultdict

# Bounding box around Brighton & Hove (generous margin around the seed stops).
MIN_LAT, MAX_LAT = 50.79, 50.88
MIN_LON, MAX_LON = -0.30, -0.08

# The app currently tracks only the Moda Hove Central pair (both directions).
# Emit just these stops; leave WHITELIST empty to emit every stop in the box.
WHITELIST = {"149000006512", "149000007515"}

# Friendly, journey-oriented names shown in the app instead of the raw stop name.
NAME_OVERRIDES = {
    "149000006512": "To town",   # Moda Hove Central (adj), towards Brighton
    "149000007515": "To school", # Moda Hove Central (opp), towards Portslade
}

# Sanity anchors: these ATCO codes MUST resolve, or the GTFS stop_id != ATCO
# assumption is wrong and we should stop rather than emit a bad catalog.
REQUIRED_ATCOS = {"149000006512", "149000007515"}

# Walk-time estimate (minutes) from the user's origin to each stop.
KNOWN_WALK_MINUTES = {
    "149000006512": 5,
    "149000007515": 6,
}

# Compass direction buses approach each stop from, used to bias the map view.
APPROACH = {
    "149000006512": "north", # To town
    "149000007515": "south", # To school
}
DEFAULT_WALK_MINUTES = 6
MAX_DESTINATIONS_PER_SERVICE = 3

# Lines to drop from the picker entirely.
EXCLUDE_LINES = {"2B"}


def service_group(line):
    """Map a raw BODS line to (group_id, display_label), or None to drop it.

    Each line is now its own option; the app offers multi-select plus an
    "All services" shortcut, so no server-side grouping is needed.
    """
    if line in EXCLUDE_LINES:
        return None
    return (line, line)


def open_text(zf, name):
    return io.TextIOWrapper(zf.open(name), encoding="utf-8-sig", newline="")


def find_member(zf, filename):
    for n in zf.namelist():
        if n.rsplit("/", 1)[-1] == filename:
            return n
    raise SystemExit(f"error: {filename} not found in GTFS zip")


def build(gtfs_path, out_path):
    with zipfile.ZipFile(gtfs_path) as zf:
        stops_name = find_member(zf, "stops.txt")
        times_name = find_member(zf, "stop_times.txt")
        trips_name = find_member(zf, "trips.txt")
        routes_name = find_member(zf, "routes.txt")

        # 1. Stops inside the bounding box.
        stops = {}
        with open_text(zf, stops_name) as f:
            for row in csv.DictReader(f):
                try:
                    lat = float(row["stop_lat"])
                    lon = float(row["stop_lon"])
                except (KeyError, ValueError):
                    continue
                if WHITELIST and row["stop_id"] not in WHITELIST:
                    continue
                if MIN_LAT <= lat <= MAX_LAT and MIN_LON <= lon <= MAX_LON:
                    stops[row["stop_id"]] = {
                        "atco": row["stop_id"],
                        "name": row.get("stop_name", "").strip(),
                        "lat": round(lat, 6),
                        "lon": round(lon, 6),
                    }
        print(f"stops in box: {len(stops)}")

        # The stop_id == ATCO assumption is confirmed if ANY anchor resolves.
        # A single missing anchor just means that seed ATCO was bogus, not that
        # the whole mapping is wrong, so only abort if none resolve.
        found = REQUIRED_ATCOS & set(stops)
        if not found:
            raise SystemExit(
                "error: no expected ATCO codes found as GTFS stop_id "
                "(stop_id != ATCO?) - aborting rather than emit a bad catalog"
            )
        for atco in sorted(REQUIRED_ATCOS - found):
            print(f"warning: anchor ATCO {atco} not present in GTFS (bogus seed?)")

        # 2. Stream stop_times, keeping only trips that touch our stops.
        stop_trips = defaultdict(set)   # stop_id -> {trip_id}
        wanted_trips = set()
        with open_text(zf, times_name) as f:
            for row in csv.DictReader(f):
                sid = row["stop_id"]
                if sid in stops:
                    tid = row["trip_id"]
                    stop_trips[sid].add(tid)
                    wanted_trips.add(tid)
        print(f"trips touching box: {len(wanted_trips)}")

        # 3. trip_id -> (route_id, headsign) for wanted trips only.
        trip_info = {}
        with open_text(zf, trips_name) as f:
            for row in csv.DictReader(f):
                tid = row["trip_id"]
                if tid in wanted_trips:
                    trip_info[tid] = (
                        row["route_id"],
                        (row.get("trip_headsign") or "").strip(),
                    )

        # 4. route_id -> short name.
        route_name = {}
        with open_text(zf, routes_name) as f:
            for row in csv.DictReader(f):
                name = (row.get("route_short_name") or row.get("route_long_name") or "").strip()
                route_name[row["route_id"]] = name

    # 5. Assemble per-stop service lists.
    catalog = []
    for sid, stop in stops.items():
        # group_id -> {"label": str, "lines": set, "dests": set}
        groups = {}
        for tid in stop_trips.get(sid, ()):
            info = trip_info.get(tid)
            if not info:
                continue
            route_id, headsign = info
            line = route_name.get(route_id, "").strip()
            if not line:
                continue
            grouped = service_group(line)
            if grouped is None:
                continue
            gid, label = grouped
            group = groups.setdefault(gid, {"label": label, "lines": set(), "dests": set()})
            group["lines"].add(line)
            if headsign:
                group["dests"].add(headsign)
        if not groups:
            continue
        stop["name"] = NAME_OVERRIDES.get(sid, stop["name"])
        stop["locality"] = ""
        stop["walkMinutes"] = KNOWN_WALK_MINUTES.get(sid, DEFAULT_WALK_MINUTES)
        if sid in APPROACH:
            stop["approach"] = APPROACH[sid]
        stop["services"] = [
            {
                "line": g["label"],
                "lines": sorted(g["lines"], key=_line_key),
                "destinations": sorted(g["dests"])[:MAX_DESTINATIONS_PER_SERVICE],
            }
            for _, g in sorted(groups.items(), key=lambda kv: _line_key(kv[1]["label"]))
        ]
        catalog.append(stop)

    catalog.sort(key=lambda s: s["name"])
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"wrote {len(catalog)} stops -> {out_path}")
    for atco in sorted(REQUIRED_ATCOS):
        stop = next((s for s in catalog if s["atco"] == atco), None)
        if stop:
            lines = ", ".join(s["line"] for s in stop["services"])
            print(f"  {atco}  {stop['name']}: {lines}")


def _line_key(line):
    """Sort '1' < '1X' < '5' < '5A' < '46' naturally."""
    num = "".join(c for c in line if c.isdigit())
    return (int(num) if num else 9999, line)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    gtfs_path = sys.argv[1]
    out_path = (
        sys.argv[2]
        if len(sys.argv) > 2
        else "MyFirstApp/MyFirstApp/Resources/stops.json"
    )
    build(gtfs_path, out_path)


if __name__ == "__main__":
    main()
