# ============================================================================
#  Road to Root -- Chapter 05 : "Capabilities"
#  Host codename: hollow-vault-01   (compose service: target-caps)
#
#  Theme: Linux file capabilities. A binary does not need the SUID bit to run
#  with power -- a single capability in its effective set is enough. Five
#  binaries on this box carry one capability too many.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
#
#  No --privileged needed: cap_setuid, cap_dac_override and cap_dac_read_search
#  are all inside Docker's default bounding set, so file caps take effect.
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        libcap2-bin \
        gcc libc6-dev \
        python3 \
        perl \
        tar \
        procps findutils coreutils iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd \
    && useradd -m -s /usr/sbin/nologin svc

# === PLANTED CAPABILITY VULNERABILITIES ====================================
# Each binary below is root-owned and NOT setuid. getcap is how you find them.

# --- Station A -- cap_setuid on a copy of python3 --------------------------
#   exploit: pyvault -c 'import os; os.setuid(0); os.system("/bin/bash")'
RUN cp "$(readlink -f /usr/bin/python3)" /usr/local/bin/pyvault \
    && setcap cap_setuid+ep /usr/local/bin/pyvault

# --- Station B -- cap_setuid on a copy of perl ----------------------------
#   exploit: plvault -e 'use POSIX qw(setuid); setuid(0); exec "/bin/bash";'
RUN cp "$(readlink -f /usr/bin/perl)" /usr/local/bin/plvault \
    && setcap cap_setuid+ep /usr/local/bin/plvault

# --- Station C -- cap_dac_read_search on a copy of tar --------------------
#   Read ANY file, no root needed. Confidentiality break, not a shell.
#   exploit: captar -cf /tmp/f.tar /root/flag.txt ; extract ; read it.
RUN cp "$(readlink -f /usr/bin/tar)" /usr/local/bin/captar \
    && setcap cap_dac_read_search+ep /usr/local/bin/captar

# --- Station D -- cap_dac_override on a custom "config writer" -------------
#   Append to ANY root-owned file. Add a sudoers rule to /etc/sudoers (which
#   stays root-owned because it already exists), then sudo to root.
#   exploit: echo 'labuser1 ALL=(ALL) NOPASSWD:ALL' | vault-write /etc/sudoers
COPY src/vault-write.c /usr/local/src/vault-write.c
RUN gcc -O2 -o /usr/local/bin/vault-write /usr/local/src/vault-write.c \
    && chown root:root /usr/local/bin/vault-write \
    && setcap cap_dac_override+ep /usr/local/bin/vault-write

# --- Station E -- cap_setuid on a bespoke launcher that trusts $SVC_CMD ----
#   setuid(0) then runs a command the caller chooses.
#   exploit: SVC_CMD=/bin/bash svc-runner
COPY src/svc-runner.c /usr/local/src/svc-runner.c
RUN gcc -O2 -o /usr/local/bin/svc-runner /usr/local/src/svc-runner.c \
    && chown root:root /usr/local/bin/svc-runner \
    && setcap cap_setuid+ep /usr/local/bin/svc-runner

# ===========================================================================

RUN printf 'R2R{c4p4b1l1t1es_are_suid_without_the_b1t}\n' > /root/flag.txt \
    && chown root:root /root/flag.txt \
    && chmod 600 /root/flag.txt

COPY motd /etc/motd
COPY MISSION.txt /home/labuser1/MISSION.txt
RUN chown labuser1:labuser1 /home/labuser1/MISSION.txt

RUN mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
