This image supports multiple CPU architectures. Docker will automatically pull the correct image for your platform.

## Published Architectures

The images on Docker Hub and GHCR are built for the platforms listed in the CI configuration (`PLATFORMS` in `ci-build-deploy.yml`):

| Architecture | Platform |
|--------------|----------|
| `386` | 32-bit x86 |
| `amd64` | 64-bit x86 |
| `arm/v6` | ARM v6 |
| `arm/v7` | ARM v7 (Raspberry Pi 2/3) |
| `arm64` | 64-bit ARM (Raspberry Pi 4/5, Apple M1) |
| `riscv64` | 64-bit RISC-V |

## Buildable Architectures

The Dockerfile itself supports every platform that **both** Alpine Linux and s6-overlay provide — the published list above plus `ppc64le` and `s390x`. Those two aren't published (no known demand), but you can build them locally:

```bash
docker buildx build --platform linux/ppc64le -t nordvpn:ppc64le .
```

(`loongarch64` is excluded — Alpine ships it but s6-overlay has no binaries; big-endian `ppc64` is excluded — s6-overlay ships it but Alpine has no port.)

## Automatic Architecture Detection

When you run `docker pull azinchen/nordvpn`, Docker automatically detects your system's architecture and pulls the appropriate image variant. No manual selection is required.

## Verifying Your Architecture

To check which architecture Docker is using:

```bash
docker image inspect azinchen/nordvpn:latest --format '{{.Architecture}}'
```

## Raspberry Pi Notes

- **Raspberry Pi 2/3**: Uses `arm/v7`
- **Raspberry Pi 4/5**: Uses `arm64` (recommended) or `arm/v7`
- **Raspberry Pi Zero/1**: Uses `arm/v6`

For best performance on Raspberry Pi 4 and newer, ensure you're running a 64-bit OS to take advantage of the `arm64` image.
