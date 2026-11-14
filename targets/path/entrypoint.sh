#!/bin/bash
set -e
mkdir -p /var/run/sshd /var/log/rtr
# The timer must keep running after a planted command exits.
/usr/local/sbin/rtr-unit-runner >/var/log/rtr/runner.log 2>&1 &
exec /usr/sbin/sshd -D -e
