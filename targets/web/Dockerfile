# ============================================================================
#  Road to Root -- Chapter 09 : "Foothold"
#  Host codename: hollow-portal-01   (compose service: target-web)
#
#  Theme: initial access. A deliberately vulnerable PHP web app ("Hollow
#  Share") exposed on the perimeter. SIX independent routes to code execution,
#  each landing a reverse shell as www-data, then ONE clean privesc to root.
#  This is the "how the breach happens" prequel to the assume-breach chapters.
#
#  Entry point: the web app at http://127.0.0.1:8080/ (compose maps it).
#  Foothold flag: /var/www/flag.txt (www-data)   Final flag: /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        libapache2-mod-php \
        php-cli \
        php-mbstring \
        php-xml \
        php-curl \
        composer \
        unzip \
        openssh-server \
        sudo \
        ca-certificates \
        curl \
        python3 \
        iproute2 \
        procps \
        netcat-traditional \
        findutils \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# --- Low-privilege shell account (kept for consistency with the range) ------
# The chapter's way in is the WEB APP, not SSH — but every target carries
# labuser1 so the lab reads the same everywhere.
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# --- The "Hollow Share" application -----------------------------------------
# Each planted bug is fenced inside its own file with
# `# === PLANTED VULNERABILITY ===` comments; see WRITEUP.md for the map.
COPY app/ /var/www/html/
RUN rm -f /var/www/html/index.html        # drop the stock Apache splash page

# Twig (Station E) — a pure-PHP templating library, installed at build time.
# Needs network during build (same as the attacker image's tool downloads).
RUN cd /var/www/html \
    && composer install --no-dev --no-interaction --no-progress \
    && test -f /var/www/html/vendor/autoload.php

# Upload sinks must be writable by the web user so uploads land, and served
# so the planted webshells run. These dirs being web-writable AND
# code-executing is the Station A/B bug.
RUN mkdir -p /var/www/html/uploads /var/www/html/shares \
    && chown -R www-data:www-data /var/www/html/uploads /var/www/html/shares \
    && chmod 0775 /var/www/html/uploads /var/www/html/shares

# === PLANTED VULNERABILITY — Apache + PHP misconfig (Stations B & D) ========
# hollow-share.conf: AddHandler runs .pht/.php5/.phtml and double extensions as
#   PHP in shares/, and AllowOverride All honours an uploaded .htaccess.
# 99-hollow.ini: allow_url_include=On turns the LFI in view.php into RCE via
#   data:// and php://input wrappers.
COPY config/hollow-share.conf /etc/apache2/conf-available/hollow-share.conf
RUN a2enconf hollow-share
COPY config/99-hollow.ini /tmp/99-hollow.ini
RUN for d in /etc/php/*/apache2/conf.d /etc/php/*/cli/conf.d; do \
        cp /tmp/99-hollow.ini "$d/99-hollow.ini"; \
    done && rm /tmp/99-hollow.ini
# === END PLANTED VULNERABILITY =============================================

# === PLANTED VULNERABILITY — capstone: www-data -> root via sudo php ========
# A "maintenance" drop-in lets the web user run php as root with no password,
# so the deploy pipeline could run artisan/composer tasks. php has a trivial
# shell escape, so this is a direct www-data -> root path once you have a shell:
#   sudo /usr/bin/php -r 'system("/bin/sh");'
RUN printf 'www-data ALL=(ALL) NOPASSWD: /usr/bin/php\n' \
         > /etc/sudoers.d/hollow-maintenance \
    && chmod 0440 /etc/sudoers.d/hollow-maintenance \
    && chown root:root /etc/sudoers.d/hollow-maintenance
# THE MISTAKE: the web user may run an interpreter as root. php -r is a shell.
# === END PLANTED VULNERABILITY =============================================

# --- The flags --------------------------------------------------------------
# Foothold flag: readable by www-data (the reverse-shell user), NOT web-served
# (it sits above the document root, so only code execution reaches it).
RUN printf 'R2R{w3b_rce_is_your_front_d00r}\n' > /var/www/flag.txt \
    && chown root:root /var/www/flag.txt \
    && chmod 0644 /var/www/flag.txt

# Final flag: proof of root. Only root can read it.
RUN printf 'R2R{www_data_t0_r00t_full_k1ll_cha1n}\n' > /root/flag.txt \
    && chown root:root /root/flag.txt \
    && chmod 600 /root/flag.txt

# --- In-world briefing (shown on SSH login, and copied for the learner) -----
COPY motd /etc/motd
COPY MISSION.txt /home/labuser1/MISSION.txt
RUN chown labuser1:labuser1 /home/labuser1/MISSION.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 22
ENTRYPOINT ["/entrypoint.sh"]
