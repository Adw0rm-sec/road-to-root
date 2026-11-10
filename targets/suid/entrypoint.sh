#!/bin/bash
set -e
# No cron needed for SUID -- just keep sshd in the foreground.
exec /usr/sbin/sshd -D -e
