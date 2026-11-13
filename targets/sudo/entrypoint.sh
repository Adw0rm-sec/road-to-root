#!/bin/bash
set -e

# Run sshd in the foreground so the container stays alive.
# -e logs to stderr so `docker logs target-sudo` shows auth attempts.
exec /usr/sbin/sshd -D -e
