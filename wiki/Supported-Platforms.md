This image supports multiple CPU architectures. Docker will automatically pull the correct image for your platform.

## Available Architectures

| Architecture | Platform |
|--------------|----------|
| `386` | 32-bit x86 |
| `amd64` | 64-bit x86 |
| `arm/v6` | ARM v6 |
| `arm/v7` | ARM v7 (Raspberry Pi 2/3) |
| `arm64` | 64-bit ARM (Raspberry Pi 4/5, Apple M1) |
| `riscv64` | 64-bit RISC-V |

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
