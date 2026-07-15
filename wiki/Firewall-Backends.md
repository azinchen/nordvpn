This image ships **both** `iptables` (nft-backed) and `iptables-legacy` (xtables). At runtime, the entrypoint automatically selects a working backend.

## Selection Logic

| Kernel version | Preferred backend | Fallback |
|---------------|-------------------|----------|
| ≥ 4.18 (new) | **nft** (`iptables`) | legacy (`iptables-legacy`) |
| < 4.18 (old, e.g. 4.4) | **legacy** (`iptables-legacy`) | nft (`iptables`) |

## Log Output

On newer kernels:
```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using IPv4 backend: iptables
```

On older systems:
```
[ENTRYPOINT] Kernel: 4.4.0-xxx
[ENTRYPOINT] Using IPv4 backend: iptables-legacy
```

## Why This Matters

- Some hosts (especially older NAS devices, VMs, or WSL) don't support nftables properly
- Docker Desktop on macOS/Windows uses a Linux VM whose kernel may behave differently
- Mixing nft and legacy rules in the same namespace causes unpredictable behavior — the entrypoint prevents this

No manual configuration is needed. The container handles backend selection automatically.
