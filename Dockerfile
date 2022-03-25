# s6 overlay builder
FROM alpine:3.15.2 AS s6-builder

ENV PACKAGE="just-containers/s6-overlay"
ENV PACKAGEVERSION="3.1.0.1"
ARG TARGETPLATFORM

RUN echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add tar=1.34-r0 \
        xz=5.2.5-r0 && \
    echo "**** create folders ****" && \
    mkdir -p /s6 && \
    echo "**** download ${PACKAGE} ****" && \
    PACKAGEPLATFORM=$(case ${TARGETPLATFORM} in \
        "linux/amd64")    echo "x86_64"   ;; \
        "linux/386")      echo "i486"     ;; \
        "linux/arm64")    echo "aarch64"  ;; \
        "linux/arm/v7")   echo "armhf"    ;; \
        "linux/arm/v6")   echo "arm"      ;; \
        *)                echo ""         ;; esac) && \
    echo "Package ${PACKAGE} platform ${PACKAGEPLATFORM} version ${PACKAGEVERSION}" && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-noarch.tar.xz" -qO /tmp/s6-overlay-noarch.tar.xz && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-${PACKAGEPLATFORM}.tar.xz" -qO /tmp/s6-overlay-binaries.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-binaries.tar.xz

# rootfs builder
FROM alpine:3.15.2 AS rootfs-builder

COPY root/ /rootfs/
RUN chmod +x /rootfs/usr/bin/*
COPY --from=s6-builder /s6/ /rootfs/

# Main image
FROM alpine:3.15.2

LABEL maintainer="Alexander Zinchenko <alexander@zinchenko.com>"

ENV TECHNOLOGY=openvpn_udp \
    RANDOM_TOP=0 \
    CHECK_CONNECTION_ATTEMPTS=5 \
    CHECK_CONNECTION_ATTEMPT_INTERVAL=10

RUN echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add bash=5.1.16-r0 \
        curl=7.80.0-r0 \
        iptables=1.8.7-r1 \
        ip6tables=1.8.7-r1 \
        jq=1.6-r1 \
        shadow=4.8.1-r1 \
        openvpn=2.5.6-r0 && \
    echo "**** create process user ****" && \
    addgroup --system --gid 912 nordvpn && \
    adduser --system --uid 912 --disabled-password --no-create-home --ingroup nordvpn nordvpn && \
    echo "**** cleanup ****" && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY --from=rootfs-builder /rootfs/ /

ENTRYPOINT ["/init"]
