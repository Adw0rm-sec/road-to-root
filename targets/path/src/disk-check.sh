#!/bin/bash
# Hollow ops disk check. sudo runs this as root. The script is not writable.
# It sets its own PATH, then calls df by name.
export PATH="/opt/admin/bin:/usr/bin:/bin"
df -h /
