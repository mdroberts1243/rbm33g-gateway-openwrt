#!/bin/sh
set -eu

TAG="gwloc"
CONF="/etc/basicstation/station.conf"
RUNTIME_JSON="/var/run/gateway_location.json"

# Acquire position (lat lon alt)
POS="$(/usr/sbin/ec25_gps_read.sh /dev/ttyUSB3 2>/dev/null || true)"
[ -n "$POS" ] || POS="$(/usr/sbin/ec25_gps_read.sh /dev/ttyUSB2 2>/dev/null || true)"

if [ -z "$POS" ]; then
  logger -t "$TAG" "No GNSS fix available; leaving station.conf unchanged"
  exit 0
fi

LAT="$(echo "$POS" | cut -d' ' -f1)"
LON="$(echo "$POS" | cut -d' ' -f2)"
ALT="$(echo "$POS" | cut -d' ' -f3)"

# Validate numeric (BusyBox grep supports -E)
echo "$LAT" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || { logger -t "$TAG" "Bad LAT: $LAT"; exit 1; }
echo "$LON" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || { logger -t "$TAG" "Bad LON: $LON"; exit 1; }
echo "$ALT" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || { logger -t "$TAG" "Bad ALT: $ALT"; exit 1; }

# Runtime JSON for your own telemetry
mkdir -p /var/run
cat > "$RUNTIME_JSON" <<JSON
{"lat":$LAT,"lon":$LON,"alt":$ALT,"source":"ec25","ts":"$(date -Iseconds)"}
JSON

# Find insertion point: first line number containing "station_conf"
SC_LINE="$(grep -n '"station_conf"[[:space:]]*:' "$CONF" | head -n1 | cut -d: -f1 || true)"
if [ -z "$SC_LINE" ]; then
  logger -t "$TAG" "ERROR: cannot find station_conf in $CONF"
  exit 2
fi

TMP="${CONF}.tmp.$$"
GPS="/tmp/gps_conf.$$"

# Build gps_conf block
cat > "$GPS" <<GPS
  "gps_conf": {
    "gw_latitude": $LAT,
    "gw_longitude": $LON,
    "gw_altitude": $ALT,
    "fixed_altitude": false
  },
GPS

# If gps_conf already exists, remove it first (line-range delete)
GC_LINE="$(grep -n '"gps_conf"[[:space:]]*:' "$CONF" | head -n1 | cut -d: -f1 || true)"
if [ -n "$GC_LINE" ]; then
  # Find end of gps_conf object: first line after GC_LINE that matches "}," with indentation
  REL_END="$(sed -n "${GC_LINE},\$p" "$CONF" | grep -n -m1 '^[[:space:]]*}[[:space:]]*,[[:space:]]*$' | cut -d: -f1 || true)"
  if [ -z "$REL_END" ]; then
    logger -t "$TAG" "ERROR: gps_conf start found but end not found; refusing to edit $CONF"
    rm -f "$GPS"
    exit 3
  fi
  END_LINE=$((GC_LINE + REL_END - 1))

  # Recompute station_conf line number after removal will happen; easiest is rebuild in two passes:
  # 1) Write file excluding gps_conf range
  # 2) Recompute station_conf insertion line on the filtered file
  sed "${GC_LINE},${END_LINE}d" "$CONF" > "$TMP"

  SC_LINE="$(grep -n '"station_conf"[[:space:]]*:' "$TMP" | head -n1 | cut -d: -f1 || true)"
  if [ -z "$SC_LINE" ]; then
    logger -t "$TAG" "ERROR: cannot find station_conf after gps_conf removal; refusing to edit"
    rm -f "$GPS" "$TMP"
    exit 4
  fi

  mv "$TMP" "$CONF"
fi

# Now insert gps_conf before station_conf by rebuilding around SC_LINE
HEAD_END=$((SC_LINE - 1))
head -n "$HEAD_END" "$CONF" > "$TMP"
cat "$GPS" >> "$TMP"
tail -n +"$SC_LINE" "$CONF" >> "$TMP"

rm -f "$GPS"
mv "$TMP" "$CONF"

logger -t "$TAG" "Updated gps_conf: lat=$LAT lon=$LON alt=$ALT; restarting Basic Station"
/etc/init.d/basicstation restart >/dev/null 2>&1 || true
