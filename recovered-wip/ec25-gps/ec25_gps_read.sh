#!/bin/sh
# Read GNSS location from Quectel EC25 via AT commands and emit JSON.
# Usage: ec25_gps_read.sh [/dev/ttyUSB2|/dev/ttyUSB3] [output_json]

set -eu

DEV="${1:-/dev/ttyUSB3}"
OUT="${2:-/var/run/gateway_location.json}"

# Basic sanity
[ -c "$DEV" ] || { echo "ERROR: $DEV not a character device" >&2; exit 2; }

# Best-effort port setup (ignore unsupported ops)
stty -F "$DEV" 115200 raw -echo 2>/dev/null || true
stty -F "$DEV" -ixon -ixoff 2>/dev/null || true

# Open bidirectional FD 3
exec 3<>"$DEV" || { echo "ERROR: cannot open $DEV" >&2; exit 3; }

drain() {
  # Drain a few lines so we don't parse stale output
  for i in 1 2 3 4 5; do
    read -t 1 -r _junk <&3 || break
  done
}

send() {
  # $1 = command without trailing \r
  printf "%s\r" "$1" >&3
}

read_until() {
  # Read up to N lines with timeout, print lines to stdout
  # $1 = per-line timeout seconds
  # $2 = max lines
  t="$1"; n="$2"
  i=0
  while [ $i -lt "$n" ]; do
    if read -t "$t" -r line <&3; then
      echo "$line"
    fi
    i=$((i+1))
  done
}

# Ensure GNSS engine on (idempotent)
drain
send "AT"
read_until 1 3 >/dev/null

drain
send "AT+QGPS=1"
read_until 2 6 >/dev/null

# Ask for one-shot location.
# +QGPSLOC: hhmmss.s,lat,lon,hdop,alt,fix,cog,spkm,spkn,date,nsat
drain
send "AT+QGPSLOC=2"

resp="$(read_until 3 12)"

# Close FD
exec 3<&- 3>&-

# Extract the +QGPSLOC line
loc_line="$(printf "%s\n" "$resp" | grep -m1 '^+QGPSLOC:' || true)"
[ -n "$loc_line" ] || { echo "ERROR: no +QGPSLOC response" >&2; exit 4; }

# Strip prefix and spaces
payload="$(echo "$loc_line" | sed 's/^+QGPSLOC:[ ]*//')"

# Split CSV into fields (BusyBox-safe)
# 1 time, 2 lat, 3 lon, 4 hdop, 5 alt, 6 fix, ... 10 date, 11 nsat
TIME="$(echo "$payload" | cut -d',' -f1)"
LAT="$( echo "$payload" | cut -d',' -f2)"
LON="$( echo "$payload" | cut -d',' -f3)"
HDOP="$(echo "$payload" | cut -d',' -f4)"
ALT="$( echo "$payload" | cut -d',' -f5)"
FIX="$( echo "$payload" | cut -d',' -f6)"
DATE="$(echo "$payload" | cut -d',' -f10)"
NSAT="$(echo "$payload" | cut -d',' -f11)"

# Basic validation
case "$LAT" in ""|0|0.0|0.00000) echo "ERROR: invalid LAT '$LAT' (no fix?)" >&2; exit 5;; esac
case "$LON" in ""|0|0.0|0.00000) echo "ERROR: invalid LON '$LON' (no fix?)" >&2; exit 6;; esac

# Produce TTN gateway status location structure (JSON)
# TTN expects latitude/longitude (degrees) and optionally altitude (meters) and source.
cat >"$OUT" <<JSON
{
  "latitude": $LAT,
  "longitude": $LON,
  "altitude": $ALT,
  "source": "ec25_gnss",
  "hdop": $HDOP,
  "fix": "$FIX",
  "nsat": "$NSAT",
  "qgps_time": "$TIME",
  "qgps_date": "$DATE"
}
JSON

echo "$LAT $LON $ALT"
