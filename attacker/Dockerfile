# Attacker box. Ubuntu + common offensive tooling (arm64-native on Apple Silicon).
# Swap the FROM line for kalilinux/kali-rolling if you want the full Kali toolset.
FROM ubuntu:25.10

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        openssh-client \
        nmap \
        netcat-traditional \
        curl wget \
        gcc make \
        python3 \
        iputils-ping \
        sshpass \
        git \
    && rm -rf /var/lib/apt/lists/*
# ca-certificates is REQUIRED: with --no-install-recommends it isn't pulled in
# automatically, and without it wget/curl HTTPS downloads fail SSL verification
# (wget exit code 5) -- which is why /opt/tools came up empty before.

# Pull LinPEAS + friends into /opt/tools so they're ready to copy to targets.
# NOTE: fail LOUDLY if a download fails (no '|| true'), and verify the files are
# non-empty -- otherwise a transient network error silently ships an empty
# /opt/tools and the box looks broken later. Needs network at build time.
RUN mkdir -p /opt/tools && cd /opt/tools \
    && wget -q --tries=3 --timeout=30 -O linpeas.sh \
         https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh \
    && wget -q --tries=3 --timeout=30 -O linux-exploit-suggester.sh \
         https://raw.githubusercontent.com/The-Z-Labs/linux-exploit-suggester/master/linux-exploit-suggester.sh \
    && chmod +x /opt/tools/*.sh \
    && test -s /opt/tools/linpeas.sh \
    && test -s /opt/tools/linux-exploit-suggester.sh \
    && echo "tools fetched: $(ls -1 /opt/tools)"

CMD ["sleep", "infinity"]
