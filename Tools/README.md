# Tools

## build_stops.py — regenerate the bundled stop catalog

The app needs to know which services actually call at each stop. BODS has **no live
API for that** — the live feed (SIRI-VM) is vehicle-centric. The authoritative
mapping lives in BODS *timetable* data, so we derive it offline and ship the result as
`MyFirstApp/Resources/stops.json`.

### Refresh procedure

1. Download the South East regional GTFS zip (this is large, ~230 MB):

   ```
   curl -L -o /tmp/gtfs_se.zip \
     "https://data.bus-data.dft.gov.uk/timetable/download/gtfs-file/south_east/"
   ```

2. Regenerate the catalog from the repo root:

   ```
   python3 Tools/build_stops.py /tmp/gtfs_se.zip MyFirstApp/Resources/stops.json
   ```

3. Sanity-check the printed summary (each tracked stop with a non-empty service list),
   then commit the updated `stops.json`.

### What it does

- Filters GTFS `stops.txt` to the `WHITELIST` of ATCO codes (currently the two Moda
  Hove Central stops). Leave `WHITELIST` empty to emit every stop in the Brighton &
  Hove bounding box instead.
- Joins `stop_times.txt` → `trips.txt` → `routes.txt` to list, per stop, the services
  that call there and their destination headsigns.
- Restores the NaPTAN `(adj)`/`(opp)` indicator (GTFS drops it) via `NAME_OVERRIDES`.
- Aborts if none of the `REQUIRED_ATCOS` resolve, i.e. if the assumption that GTFS
  `stop_id` equals the ATCO code no longer holds.

### Note

`stops.json` is a point-in-time snapshot of the timetable. Re-run this whenever routes
change. Adding a stop = add its ATCO to `WHITELIST` (and, if you want, `NAME_OVERRIDES`
/ `KNOWN_WALK_MINUTES`) and regenerate.
