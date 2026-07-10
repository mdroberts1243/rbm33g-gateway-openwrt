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
