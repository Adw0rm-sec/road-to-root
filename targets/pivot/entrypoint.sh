#!/bin/bash
set -e
mkdir -p /var/run/sshd

# Station A: the internal diagnostics web app, bound to loopback, run as ROOT.
# (Running it as root + shelling out on user input is the vulnerability.)
python3 /opt/intranet/intranet.py >/var/log/intranet.log 2>&1 &

# Station B: cron must run for the root updater to fire.
service cron start || cron

exec /usr/sbin/sshd -D -e
