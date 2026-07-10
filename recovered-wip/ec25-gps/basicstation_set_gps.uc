#!/usr/bin/ucode

import { readfile, writefile } from "fs";
import { parse, stringify } from "json";

let conf_path = "/etc/basicstation/station.conf";
let lat = +ARGV[0];
let lon = +ARGV[1];
let alt = +ARGV[2];

if (!isfinite(lat) || !isfinite(lon) || !isfinite(alt)) {
  die("usage: basicstation_set_gps.uc <lat> <lon> <alt>\n");
}

let raw = readfile(conf_path);
if (!raw) die("cannot read " + conf_path + "\n");

let j = parse(raw);
if (!j) die("cannot parse JSON in " + conf_path + "\n");

j.gps_conf = {
  gw_latitude: lat,
  gw_longitude: lon,
  gw_altitude: alt,
  fixed_altitude: false
};

let out = stringify(j, "\t") + "\n";
writefile(conf_path, out);
print("updated gps_conf in " + conf_path + "\n");

