#!/bin/bash
set -e
mkdir -p /var/run/sshd /var/log/rtr

# --- Station B plumbing: root's passwordless ssh key to svcbackup@localhost ---
# The rsync backup job uses this. The EXPLOIT (-e sh payload) never touches ssh;
# this just lets the benign job run without prompting.
if [ ! -f /root/.ssh/id_ed25519 ]; then
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
  install -d -m 700 -o svcbackup -g svcbackup /home/svcbackup/.ssh
  cp /root/.ssh/id_ed25519.pub /home/svcbackup/.ssh/authorized_keys
  chown svcbackup:svcbackup /home/svcbackup/.ssh/authorized_keys
  chmod 600 /home/svcbackup/.ssh/authorized_keys
  printf 'Host localhost\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' \
    > /root/.ssh/config
  chmod 600 /root/.ssh/config
fi

# Cron MUST be running or none of the wildcard jobs ever fire.
service cron start || cron

exec /usr/sbin/sshd -D -e
