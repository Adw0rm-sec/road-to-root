#!/bin/bash
set -e

# Make the Apache logs readable by www-data so the LFI log-poisoning path
# (Station D) works: www-data must be able to *read* the access log it poisons.
# By default /var/log/apache2 is 0750 root:adm (www-data can't even traverse it)
# and the log file is 0640. We open both up — a planted misconfig in the spirit
# of "verbose logging left world-readable". Apache opens the files for append
# without changing an existing file's mode, so 0644 survives.
mkdir -p /var/log/apache2
chmod 0755 /var/log/apache2
: > /var/log/apache2/access.log
: > /var/log/apache2/error.log
chmod 0644 /var/log/apache2/access.log /var/log/apache2/error.log

# Keep the box consistent with the rest of the range: sshd available for the
# labuser1 account, even though the chapter's way in is the web app.
mkdir -p /var/run/sshd
/usr/sbin/sshd

# Run Apache in the foreground so the container stays alive and `docker logs
# target-web` shows requests/errors. apache2ctl sources /etc/apache2/envvars.
exec apache2ctl -D FOREGROUND
