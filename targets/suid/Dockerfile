# ============================================================================
#  Road to Root -- Chapter 01 : "Set & Forget"
#  Host codename: hollow-fileproc-01   (compose service: target-suid)
#
#  Theme: SUID privilege escalation -- FIVE independent paths to root in one box.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        build-essential \
        python3 \
        findutils \
        coreutils \
        iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# --- Low-privilege foothold account ----------------------------------------
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# === PLANTED SUID VULNERABILITIES ==========================================

# --- Station A -- GTFOBins: SUID on a legit binary (find) -------------------
#   exploit: /usr/local/bin/suid-find . -exec /bin/sh -p \; -quit
RUN cp /usr/bin/find /usr/local/bin/suid-find \
    && chmod 4755 /usr/local/bin/suid-find

# --- Station B -- GTFOBins: SUID on an interpreter (python3) ----------------
#   exploit: /usr/local/bin/suid-python -c 'import os;os.setuid(0);os.system("/bin/sh")'
RUN cp /usr/bin/python3 /usr/local/bin/suid-python \
    && chmod 4755 /usr/local/bin/suid-python

# --- Station C -- custom SUID binary, PATH hijack (calls bare 'du') ---------
#   exploit: put a fake 'du' early in PATH, then run /usr/local/bin/logstats
COPY src/pathvuln.c /tmp/pathvuln.c
RUN gcc -o /usr/local/bin/logstats /tmp/pathvuln.c \
    && chmod 4755 /usr/local/bin/logstats \
    && rm /tmp/pathvuln.c

# --- Station D -- custom SUID binary, command injection --------------------
#   exploit: /usr/local/bin/logreader 'x; /bin/bash'
COPY src/injvuln.c /tmp/injvuln.c
RUN gcc -o /usr/local/bin/logreader /tmp/injvuln.c \
    && chmod 4755 /usr/local/bin/logreader \
    && rm /tmp/injvuln.c

# --- Station E -- custom SUID binary, shared-object injection ---------------
#   The 'report' tool loads libgreet.so from /opt/lab/lib via a baked-in RPATH.
#   That directory is world-writable -> replace the .so and your code runs as root.
#   exploit: rm /opt/lab/lib/libgreet.so; gcc -shared -fPIC your evil .so in its place; run report
COPY src/libgreet.c /tmp/libgreet.c
COPY src/report.c   /tmp/report.c
RUN mkdir -p /opt/lab/lib \
    && gcc -shared -fPIC -o /opt/lab/lib/libgreet.so /tmp/libgreet.c \
    && gcc -o /usr/local/bin/report /tmp/report.c \
         -L/opt/lab/lib -lgreet -Wl,-rpath,/opt/lab/lib \
    && chmod 4755 /usr/local/bin/report \
    && chmod 0777 /opt/lab/lib \
    && rm /tmp/libgreet.c /tmp/report.c
# THE MISTAKE: a world-writable directory (0777) sits on a SUID binary's RPATH.

# ===========================================================================

# --- The flag: proof of root. Only root can read it. -----------------------
RUN printf 'R2R{su1d_b1ts_are_forever_check_your_perms}\n' > /root/flag.txt \
    && chown root:root /root/flag.txt \
    && chmod 600 /root/flag.txt

# --- In-world mission briefing (shown on SSH login) ------------------------
COPY motd /etc/motd
COPY MISSION.txt /home/labuser1/MISSION.txt
RUN chown labuser1:labuser1 /home/labuser1/MISSION.txt

RUN mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
