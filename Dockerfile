# s6 overlay builder
FROM alpine:3.22.2 AS s6-builder

ENV PACKAGE="just-containers/s6-overlay"
ENV PACKAGEVERSION="3.2.1.0"

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add \
        tar=1.35-r3 \
        xz=5.8.1-r0 \
        && \
    echo "**** create folders ****" && \
    mkdir -p /s6 && \
    echo "**** download ${PACKAGE} ****" && \
    s6_arch=$(case $(uname -m) in \
        i?86)           echo "i486"        ;; \
        x86_64)         echo "x86_64"      ;; \
        aarch64)        echo "aarch64"     ;; \
        armv6l)         echo "arm"         ;; \
        armv7l)         echo "armhf"       ;; \
        ppc64le)        echo "powerpc64le" ;; \
        riscv64)        echo "riscv64"     ;; \
        s390x)          echo "s390x"       ;; \
        *)              echo ""            ;; esac) && \
    echo "Package ${PACKAGE} platform ${PACKAGEPLATFORM} version ${PACKAGEVERSION}" && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-noarch.tar.xz" -qO /tmp/s6-overlay-noarch.tar.xz && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-${s6_arch}.tar.xz" -qO /tmp/s6-overlay-binaries.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-binaries.tar.xz

# rootfs builder
FROM alpine:3.22.2 AS rootfs-builder

ARG IMAGE_VERSION=N/A \
    BUILD_DATE=N/A

RUN echo "**** install security fix packages ****" && \
    echo "**** end run statement ****"

COPY root/ /rootfs/
RUN chmod +x /rootfs/usr/local/bin/* || true && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/run  || true && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/finish || true && \
    chmod 644 /rootfs/usr/local/share/nordvpn/data/*.json && \
    chmod 644 /rootfs/usr/local/share/nordvpn/data/template.ovpn && \
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

# Main image
FROM alpine:3.22.2

ARG IMAGE_VERSION=N/A \
    BUILD_DATE=N/A

LABEL org.opencontainers.image.authors="Alexander Zinchenko <alexander@zinchenko.com>" \
      org.opencontainers.image.description="OpenVPN client docker container that routes other containers' traffic through NordVPN servers automatically." \
      org.opencontainers.image.source="https://github.com/azinchen/nordvpn" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.title="NordVPN OpenVPN Docker Container" \
      org.opencontainers.image.url="https://github.com/azinchen/nordvpn" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV PATH=/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=120000

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    # PLATFORM_VERSIONS: bind-tools: default=9.20.15-r0 armv7l=9.20.13-r0 riscv64=9.20.13-r0
    bind_tools_version=$(case $(uname -m) in \
        armv7l)         echo "9.20.13-r0"  ;; \
        riscv64)        echo "9.20.13-r0"  ;; \
        *)              echo "9.20.15-r0" ;; esac) && \
    apk --no-cache --no-progress add \
        curl=8.14.1-r2 \
        iptables=1.8.11-r1 \
        iptables-legacy=1.8.11-r1 \
        jq=1.8.0-r0 \
        shadow=4.17.3-r0 \
        shadow-login=4.17.3-r0 \
        openvpn=2.6.14-r0 \
        bind-tools=${bind_tools_version} \
        netcat-openbsd=1.229.1-r0 \
        && \
    echo "**** create process user ****" && \
    addgroup --system --gid 912 nordvpn && \
    adduser --system --uid 912 --disabled-password --no-create-home --ingroup nordvpn nordvpn && \
    echo "**** cleanup ****" && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY --from=rootfs-builder /rootfs/ /

ENTRYPOINT ["/usr/local/bin/entrypoint"]
