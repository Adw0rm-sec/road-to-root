#!/bin/bash
set -e
mkdir -p /var/run/sshd
# setcap xattrs survive the image layers; nothing to arm at boot. Just sshd.
exec /usr/sbin/sshd -D -e
