#!/bin/bash
# ExecStart of rtr-disk.service. PATH comes from the unit file, not from here.
df -P / | head -n 2
