# Semtech Basic Station on M33G (TTN Cloud)

Target:
- Hardware: MikroTik RouterBOARD M33G (MT7621A)
- Radio: SX1302 CoreCell via USB (/dev/ttyACM0)
- Network: The Things Stack (TTN Cloud), cluster: nam1
- Region: US915 (TTN FSB2)

## Image-baked files (OpenWrt overlay)

These are built into firmware via `openwrt/files/...`:

- `/etc/basicstation/gateway.id`  
  EUI used by Basic Station (derived from WAN MAC, EUI64 format)

- `/etc/basicstation/station.conf`  
  Includes `SX1302_conf` (USB device path + radio specifics) and `station_conf`
  including `radio_init` (rinit.sh)

- `/etc/basicstation/tc.uri`  
  Example: `wss://nam1.cloud.thethings.network:8887`

- `/etc/basicstation/tc.trust`  
  CA bundle path or PEM (we use the system CA bundle)

- `/etc/basicstation/rinit.sh`  
  Radio init helper used by station at startup

- `/etc/init.d/basicstation`  
  Init script to start/stop station

- `/etc/uci-defaults/90-basicstation`  
  First boot script that enables Basic Station only after a per-device key
  has been provisioned.

## Per-device provisioning (NOT baked into image)

A gateway-specific LNS authentication key must be provisioned at:

- `/etc/secret/basicstation/tc.key`

Expected file format (must end with CRLF):
- `Authorization: Bearer <LNS_KEY>\r\n`

On first boot, if `/etc/secret/basicstation/tc.key` exists and is non-empty:
- it is copied to `/etc/basicstation/tc.key` with mode 0600
- Basic Station is enabled and started

If the key is missing:
- Basic Station remains disabled (safe-by-default)

## Operational procedure (manual provisioning)

1. Place key on the device:
   - create: `/etc/secret/basicstation/`
   - write:  `/etc/secret/basicstation/tc.key` (0600)

2. Enable and start:
   - `/etc/init.d/basicstation enable`
   - `/etc/init.d/basicstation start`

3. Verify logs:
   - run `station` manually for foreground debug:
     - `/usr/bin/station --home /etc/basicstation --log-level INFO`

Expected connection behavior:
- Station connects to TTN INFOS and is redirected to `/traffic/eui-<EUI>`
- TTN console shows the gateway as CONNECTED (green)

## Notes

- We intentionally do not use UDP Packet Forwarder.
- CUPS is optional; for LNS-only operation we configure TC only.
