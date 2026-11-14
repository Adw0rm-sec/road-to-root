#!/bin/bash
# Root job that loads /etc/environment the way a PAM login would, then
# runs uname by name. Whatever PATH that file sets is the PATH used here.
set -a
# shellcheck disable=SC1091
. /etc/environment
set +a
uname -s
