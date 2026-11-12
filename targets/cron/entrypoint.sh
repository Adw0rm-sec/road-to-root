#!/bin/bash
set -e

# Cron MUST be running or none of the privesc paths can ever fire.
service cron start || cron

# Run sshd in the foreground so the container stays alive.
# -e logs to stderr so `docker logs target-cron` shows auth attempts.
exec /usr/sbin/sshd -D -e
