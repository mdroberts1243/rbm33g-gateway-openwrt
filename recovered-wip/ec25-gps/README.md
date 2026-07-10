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
