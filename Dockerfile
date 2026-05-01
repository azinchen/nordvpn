ARG OPENVPN_VERSION=2.7.4
ARG OPENVPN_XOR_PATCH_VERSION=2.7.3
ARG IMAGE_VERSION=N/A
ARG BUILD_DATE=N/A

# s6 overlay builder
FROM alpine:3.23.4 AS s6-builder

ARG TARGETARCH
ARG TARGETVARIANT

ENV PACKAGE="just-containers/s6-overlay"
ENV PACKAGEVERSION="3.2.2.0"

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add \
        tar=1.35-r4 \
        xz=5.8.3-r0 \
        && \
    echo "**** create folders ****" && \
    mkdir -p /s6 && \
    echo "**** download ${PACKAGE} ****" && \
    echo "Target arch: ${TARGETARCH}${TARGETVARIANT}" && \
    # Map Docker TARGETARCH to s6-overlay architecture names
    case "${TARGETARCH}${TARGETVARIANT}" in \
        amd64)      s6_arch="x86_64" ;; \
        arm64)      s6_arch="aarch64" ;; \
        armv7)      s6_arch="arm" ;; \
        armv6)      s6_arch="armhf" ;; \
        386)        s6_arch="i686" ;; \
        ppc64)      s6_arch="powerpc64" ;; \
        ppc64le)    s6_arch="powerpc64le" ;; \
        riscv64)    s6_arch="riscv64" ;; \
        s390x)      s6_arch="s390x" ;; \
        *)          s6_arch="x86_64" ;; \
    esac && \
    echo "Package ${PACKAGE} platform ${PACKAGEPLATFORM} version ${PACKAGEVERSION}" && \
    s6_url_base="https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}" && \
    wget -q "${s6_url_base}/s6-overlay-noarch.tar.xz" -qO /tmp/s6-overlay-noarch.tar.xz && \
    wget -q "${s6_url_base}/s6-overlay-${s6_arch}.tar.xz" -qO /tmp/s6-overlay-binaries.tar.xz && \
    wget -q "${s6_url_base}/s6-overlay-symlinks-noarch.tar.xz" -qO /tmp/s6-overlay-symlinks-noarch.tar.xz && \
    wget -q "${s6_url_base}/s6-overlay-symlinks-arch.tar.xz" -qO /tmp/s6-overlay-symlinks-arch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-binaries.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

# OpenVPN XOR builder
FROM alpine:3.23.4 AS openvpn-builder

ARG OPENVPN_VERSION
ARG OPENVPN_XOR_PATCH_VERSION

RUN echo "**** install build dependencies ****" && \
    apk --no-cache --no-progress add \
        autoconf=2.72-r1 \
        automake=1.18.1-r0 \
        build-base=0.5-r3 \
        curl=8.17.0-r1 \
        jq=1.8.1-r0 \
        libcap-ng-dev=0.8.5-r0 \
        linux-headers=6.16.12-r0 \
        libnl3-dev=3.11.0-r0 \
        libtool=2.5.4-r2 \
        lz4-dev=1.10.0-r0 \
        lzo-dev=2.10-r5 \
        openssl-dev=3.5.6-r0 \
        patch=2.8-r0 \
        && \
    echo "**** download OpenVPN ${OPENVPN_VERSION} source ****" && \
    curl -sSL "https://github.com/OpenVPN/openvpn/archive/refs/tags/v${OPENVPN_VERSION}.tar.gz" \
        -o /tmp/openvpn.tar.gz && \
    mkdir -p /tmp/openvpn && \
    tar xf /tmp/openvpn.tar.gz -C /tmp/openvpn --strip-components=1 && \
    echo "**** apply Tunnelblick XOR patches ${OPENVPN_XOR_PATCH_VERSION} ****" && \
    cd /tmp/openvpn && \
    PATCH_URLS=$(curl -sf "https://api.github.com/repos/Tunnelblick/Tunnelblick/contents/third_party/sources/openvpn/openvpn-${OPENVPN_XOR_PATCH_VERSION}/patches" \
        | jq -r '.[] | select(.name | contains("xorpatch")) | .download_url' | sort) && \
    [ -n "$PATCH_URLS" ] || { echo "ERROR: No XOR patches found for ${OPENVPN_XOR_PATCH_VERSION}"; exit 1; } && \
    for url in $PATCH_URLS; do \
        echo "Applying $(basename "$url")" && \
        curl -sSL "$url" | patch -p1 || exit 1; \
    done && \
    echo "**** build OpenVPN with XOR support ****" && \
    autoreconf -ivf && \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/openvpn \
        --enable-iproute2 \
        --enable-plugins \
        --enable-x509-alt-username \
        --enable-lzo \
        --enable-lz4 \
        --disable-plugin-auth-pam && \
    make -j"$(nproc)" && \
    strip src/openvpn/openvpn && \
    cp src/openvpn/openvpn /tmp/openvpn-binary

# rootfs builder
FROM alpine:3.23.4 AS rootfs-builder

ARG IMAGE_VERSION
ARG BUILD_DATE

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add \
        jq=1.8.1-r0 \
        && \
    echo "**** end run statement ****"

COPY root/ /rootfs/
RUN chmod +x /rootfs/usr/local/bin/* || true && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/run  || true && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/finish || true && \
    chmod +x /rootfs/etc/openvpn/*.sh && \
    chmod 644 /rootfs/usr/local/share/nordvpn/data/*.json && \
    chmod 644 /rootfs/usr/local/share/nordvpn/data/template.ovpn && \
    for f in /rootfs/usr/local/share/nordvpn/data/*.json; do \
        jq -c . "$f" > "$f.tmp" && mv "$f.tmp" "$f"; \
    done && \
    safe_sed() { \
        local pattern="$1"; \
        local replacement="$2"; \
        local file="$3"; \
        local delim; \
        for delim in '/' '|' '#' '@' '%' '^' '&' '*' '+' '-' '_' '=' ':' ';' '<' '>' ',' '.' '?' '~' '`' '!' '$' '(' ')' '[' ']' '{' '}' '\\' '"' "'"; do \
            if [[ "$replacement" != *"$delim"* ]]; then \
                sed -i "s$delim$pattern$delim$replacement$delim g" "$file"; \
                return; \
            fi; \
        done; \
        echo "No safe delimiter found for $pattern in $file"; \
    } && \
    safe_sed "__IMAGE_VERSION__" "${IMAGE_VERSION}" /rootfs/usr/local/bin/entrypoint && \
    safe_sed "__BUILD_DATE__" "${BUILD_DATE}" /rootfs/usr/local/bin/entrypoint
COPY --from=s6-builder /s6/ /rootfs/
COPY --from=openvpn-builder /tmp/openvpn-binary /rootfs/usr/sbin/openvpn

# Main image
FROM alpine:3.23.4

ARG TARGETPLATFORM
ARG OPENVPN_VERSION
ARG IMAGE_VERSION
ARG BUILD_DATE

LABEL org.opencontainers.image.authors="Alexander Zinchenko <alexander@zinchenko.com>" \
      org.opencontainers.image.description="OpenVPN client docker container that routes other containers' traffic through NordVPN servers automatically." \
      org.opencontainers.image.source="https://github.com/azinchen/nordvpn" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.title="NordVPN OpenVPN Docker Container" \
      org.opencontainers.image.url="https://github.com/azinchen/nordvpn" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      com.nordvpn.openvpn.version="${OPENVPN_VERSION}" \
      com.nordvpn.openvpn.xor="true"

ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=120000

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    echo "Target platform: ${TARGETPLATFORM}" && \
    apk --no-cache --no-progress add \
        curl=8.17.0-r1 \
        iptables=1.8.11-r1 \
        iptables-legacy=1.8.11-r1 \
        jq=1.8.1-r0 \
        shadow=4.18.0-r0 \
        shadow-login=4.18.0-r0 \
        libcap-ng=0.8.5-r0 \
        libnl3=3.11.0-r0 \
        lz4-libs=1.10.0-r0 \
        lzo=2.10-r5 \
        bind-tools=9.20.22-r0 \
        && \
    echo "**** create process user ****" && \
    addgroup --system --gid 912 nordvpn && \
    adduser --system --uid 912 --disabled-password --no-create-home --ingroup nordvpn nordvpn && \
    echo "**** cleanup ****" && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY --from=rootfs-builder /rootfs/ /

ENTRYPOINT ["/usr/local/bin/entrypoint"]
