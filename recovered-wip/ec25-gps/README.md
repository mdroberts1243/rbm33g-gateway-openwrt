# Recovered EC25 GPS Work-in-Progress

Recovered from the writable overlay of the running M33G gateway on
2026-07-10.

These files were not present in any reachable Git commit, branch, tag,
stash, or untracked path in the OpenWrt checkout:

- `ec25-gps`
- `ec25_gps_read.sh`
- `update_gateway_location.sh`
- `basicstation_set_gps.uc`

The current branch, `wip/gps-lte-position`, contains only commit
`c29476ba03`, which adds `diffconfig-modem.txt`. These recovered files
appear to be later experimental work performed directly on the gateway.

They are archived here for review and must not be copied into the
firmware `files/` overlay unchanged. Known review items include:

- serial-port access coordination
- explicit `stty` and `ucode` dependencies
- atomic JSON and configuration writes
- avoidance of unnecessary flash writes
- avoidance of unnecessary Basic Station restarts
- GNSS acquisition timeout and cold-start behaviour
- interaction with the production monitoring/self-healing framework

## Historical conclusion: TTN location propagation

Testing confirmed that writing `gps_conf` into
`/etc/basicstation/station.conf` does not cause The Things Stack to receive
the gateway coordinates in Basic Station status messages.

The observed `gs.status.receive` event contained version and feature
information only; it did not contain latitude, longitude, altitude,
`location`, or `antenna_locations`.

`gps_conf` is Basic Station configuration. It does not provide a template
for the protocol messages generated internally by the `station` executable.
Adding location to TTN status through this path would require compatible
gateway-side Basic Station protocol support and corresponding server-side
mapping in The Things Stack. The hosted TTN Gateway Server is outside this
project's control.

The production TTN-visible location mechanism is therefore a guarded update
to the TTN gateway registry through its authenticated API. TTN should remain
configured for manually/registry-set location rather than status-derived
location.

This is separate from local GNSS use. The gateway should continue to retain
the current validated fix in volatile runtime state for diagnostics,
monitoring, and registry-update decisions.

## Fixed-gateway publication policy

These gateways are deployed as fixed infrastructure. GNSS is used for
commissioning, relocation detection, diagnostics, and correction of stale
registry coordinates. It is not used for continuous tracking.

A production implementation should:

- acquire several valid fixes before accepting a location;
- require GNSS fix quality greater than zero;
- require at least five satellites;
- require HDOP no worse than 2.5;
- average or otherwise reject inconsistent fixes;
- compare the accepted fix with the last successfully published TTN
  registry location;
- publish only when no prior registry location is recorded or when the
  gateway has moved materially;
- use an initial horizontal movement threshold of 75 metres;
- use an initial altitude threshold of 30 metres;
- record movement beyond the threshold as a possible relocation event;
- avoid periodic registry writes when the location has not changed;
- persist last-published state only after a successful TTN API response.

The current live fix should remain volatile under `/var/run`. Persistent
last-published state should be written infrequently to minimize flash wear.

## Revised production design: use the EC25 NMEA port directly

Further testing confirmed that the deployed Basic Station binary includes
the Linux GPS implementation from `gps.c`.

The EC25 exposes a continuous NMEA stream on:

    /dev/ttyUSB1

A valid observed sentence was:

    $GPGGA,200035.00,4517.527623,N,07551.847321,W,1,07,0.8,133.3,M,-36.0,M,,*52

Adding the following property to the `station_conf` object activates the
existing Basic Station GPS path:

    "gps": "/dev/ttyUSB1"

After restart, Basic Station successfully reported:

    GPS move 0.0000000,0.0000000 => 45.2921219,-75.8641510
    GPS fix: 45.2921219,-75.8641510 alt=133.3 dilution=0.800000 satellites=7 quality=1

Therefore, the old `AT+QGPSLOC=2` polling script is not required to provide
live GNSS data to Basic Station. The production firmware should configure
Basic Station to read `/dev/ttyUSB1` directly.

The recovered polling scripts remain useful as historical prototypes and
possibly as independent diagnostic tools, but they should not be the
primary Basic Station location source.

Hosted TTN currently exposes the Basic Station `gps` feature in
`gs.status.receive`, but the observed status event still does not contain
latitude, longitude, altitude, or `antenna_locations`. TTN-visible location
must therefore still be updated through the gateway registry API unless
server-side Basic Station GPS-event handling changes.

Do not configure `"pps": "gps"` until a valid hardware PPS path has been
identified and tested. NMEA time sentences alone are not equivalent to a
PPS timing signal.
