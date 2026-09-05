FROM golang:1.25-alpine AS tools

RUN apk add --no-cache git
RUN GOBIN=/usr/local/bin go install github.com/caddyserver/caddy/v2/cmd/caddy@v2.10.2
RUN GOBIN=/usr/local/bin go install github.com/DarthSim/hivemind@latest

FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG FORGEJO_VERSION=11.0.14

ENV LANG=C.UTF-8
ENV GITEA_WORK_DIR=/data/forgejo
ENV GITEA_CUSTOM=/data/forgejo/custom
ENV GITEA_TEMP=/tmp/gitea
ENV GITEA_APP_INI=/data/forgejo/custom/conf/app.ini
ENV FORGEJO_HOME=/data/forgejo/git

RUN apt-get -qq update && \
    apt-get -qq install --no-install-recommends -y \
        bash \
        ca-certificates \
        crudini \
        curl \
        gettext-base \
        git \
        locales \
        openssh-client \
        restic \
        sqlite3 \
        tzdata \
        xz-utils && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/*
RUN printf 'C.UTF-8 UTF-8\n' > /etc/locale.gen && \
    locale-gen && \
    groupadd -g 1001 forgejo && \
    useradd -d /data/forgejo/git -M -u 1001 -g forgejo -s /bin/sh forgejo

RUN arch="${TARGETARCH:-$(dpkg --print-architecture)}" && \
    case "$arch" in \
        amd64|arm64) forgejo_arch="$arch" ;; \
        *) echo "Unsupported Forgejo architecture: $arch" >&2; exit 1 ;; \
    esac && \
    curl -fLo /usr/local/bin/forgejo "https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}/forgejo-${FORGEJO_VERSION}-linux-${forgejo_arch}" && \
    chmod 755 /usr/local/bin/forgejo && \
    ln -sf /usr/local/bin/forgejo /usr/local/bin/gitea

RUN mkdir -p /etc/caddy /etc/templates /etc/auth /tmp/gitea /data /data/forgejo

COPY --from=tools /usr/local/bin/caddy /usr/local/bin/hivemind /usr/local/bin/
COPY Caddyfile /etc/caddy/Caddyfile
COPY Procfile /etc/Procfile
COPY forgejo-app.ini.tmpl /etc/templates/forgejo-app.ini.tmpl
COPY bin/ /usr/local/bin/

RUN chmod 755 /usr/local/bin/* && \
    chown -R forgejo:forgejo /data/forgejo /tmp/gitea

CMD ["/usr/local/bin/start-services.sh"]
