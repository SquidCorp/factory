# Headless Orca runtime built from the official Linux AppImage.
# See https://github.com/stablyai/orca and docs/reference/headless-linux-server.md
FROM ubuntu:24.04

ARG ORCA_VERSION=v1.4.244
ARG NODE_VERSION=24.22.2
ARG TARGETARCH
ARG PI_PROFILE_SOURCE=git:https://github.com/SquidCorp/pi-profile

ENV DEBIAN_FRONTEND=noninteractive \
    LIBGL_ALWAYS_SOFTWARE=1 \
    ELECTRON_DISABLE_SANDBOX=1 \
    ORCA_PORT=6768

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash ca-certificates curl file git jq openssh-client procps python3 \
        ripgrep unzip xz-utils xvfb zlib1g-dev \
        libgtk-3-0t64 libpango-1.0-0 libcairo2 \
        libnss3 libgbm1 libdrm2 libasound2t64 libcups2t64 libxkbcommon0 \
        libatk1.0-0t64 libatk-bridge2.0-0t64 libatspi2.0-0t64 \
        libx11-xcb1 libxcb-dri3-0 libxcomposite1 libxdamage1 libxfixes3 \
        libxrandr2 libxrender1 libxss1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

# Node 22 for the pi coding agent (Ubuntu 24 ships Node 18).
RUN case "${TARGETARCH}" in \
      amd64) nodearch=x64 ;; \
      arm64) nodearch=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${nodearch}.tar.xz" \
         | tar -xJ -C /usr/local --strip-components=1 \
    && node -v && npm -v

RUN if [ "${TARGETARCH}" = arm64 ]; then asset=orca-linux-arm64.AppImage; else asset=orca-linux.AppImage; fi \
    && curl -fL --retry 3 -o /tmp/orca.AppImage \
         "https://github.com/stablyai/orca/releases/download/${ORCA_VERSION}/${asset}" \
    && chmod +x /tmp/orca.AppImage \
    && cd /opt && /tmp/orca.AppImage --appimage-extract >/dev/null \
    && mv /opt/squashfs-root /opt/orca \
    && chmod -R a+rX /opt/orca \
    && rm /tmp/orca.AppImage

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
    && pi --version

RUN useradd --create-home --shell /bin/bash orca \
    && mkdir -p /home/orca/.local/bin \
    && chown -R orca:orca /home/orca

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY git-credential-github-token /usr/local/bin/git-credential-github-token
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/git-credential-github-token

USER orca
WORKDIR /home/orca

ENV HOME=/home/orca \
    PATH=/home/orca/.local/bin:/opt/orca/resources/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    npm_config_cache=/tmp/npm-cache

# Install pi-profile into the image, then snapshot ~/.pi so a named volume
# can restore it on first boot without hiding the global `pi` binary.
RUN pi install "${PI_PROFILE_SOURCE}" \
    && pi list \
    && mkdir -p /tmp/pi-seed \
    && cp -a /home/orca/.pi /tmp/pi-seed/.pi

USER root
RUN mkdir -p /opt/pi-seed \
    && mv /tmp/pi-seed/.pi /opt/pi-seed/.pi \
    && chown -R orca:orca /opt/pi-seed
USER orca

# Chromium cannot create its sandbox namespaces in an unprivileged
# container; the container is the isolation boundary instead.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["serve"]
