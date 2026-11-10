#!/bin/bash
set -e

# Start the cron daemon (without this, the cron privesc can never fire)
service cron start

# Run sshd in the foreground so the container stays alive.
# -e logs to stderr so `docker logs target-cron` shows auth attempts.
exec /usr/sbin/sshd -D -e
