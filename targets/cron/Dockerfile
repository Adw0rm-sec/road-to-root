# Target: cron privilege escalation (world-writable root cron script)
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        cron \
        sudo \
        iproute2 \
    && rm -rf /var/lib/apt/lists/*

# --- Low-privilege foothold account ---
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# --- PLANTED VULNERABILITY -------------------------------------------------
# A root cron job runs backup.sh every minute. The script is world-writable,
# so labuser1 can edit what root executes.  (chmod 777 == the admin mistake)
RUN mkdir -p /opt/scripts \
    && printf '#!/bin/bash\ntar -czf /tmp/backup.tgz /var/log >/dev/null 2>&1\n' \
         > /opt/scripts/backup.sh \
    && chmod 777 /opt/scripts/backup.sh \
    && printf '* * * * * root /opt/scripts/backup.sh\n' > /etc/cron.d/lab_backup \
    && chmod 644 /etc/cron.d/lab_backup
# ---------------------------------------------------------------------------

RUN mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
