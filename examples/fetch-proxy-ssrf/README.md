# Fetch Proxy + SSRF Example

Runnable walkthrough for Pipelock’s `/fetch?url=...` transport: URL scanning
(core SSRF literal-IP floor), plus response scanning that blocks prompt-injection
payloads in fetched content.

This example is fully local. A tiny HTTP echo/inject server and pipelock both
bind on `127.0.0.1`. No external network access is required.

## What This Demonstrates

| Check | What it proves |
|-------|----------------|
| Clean `/fetch` | Local echo page returns content with `blocked: false` |
| Metadata SSRF | `http://169.254.169.254/...` is blocked before dial |
| Private IP SSRF | `http://10.0.0.1/` is blocked by the core literal floor |
| Response injection | Local page with injection text is blocked on `/fetch` |

## Prerequisites

- `pipelock` on `PATH`, or set `PIPELOCK_BIN`
- Bash 3.2+, `curl`, Python 3

```bash
make build
export PIPELOCK_BIN="$PWD/pipelock"
```

## Quick Verify

```bash
./verify.sh
```

## Manual Try

```bash
pipelock run --config examples/fetch-proxy-ssrf/pipelock.yaml
```

```bash
curl -sS -G --data-urlencode "url=http://127.0.0.1:ECHO_PORT/" \
  "http://127.0.0.1:8888/fetch"

curl -sS -G --data-urlencode "url=http://169.254.169.254/latest/meta-data/" \
  "http://127.0.0.1:8888/fetch"
```

## Config Notes

`internal: []` turns off DNS-based SSRF only. The core literal-IP floor still
blocks private and metadata IPs unless listed in `ssrf.ip_allowlist`. Loopback
is allowlisted so the verify harness can fetch the local echo server.

See `../../docs/guides/transport-modes.md`.

## Contributing

Improvements welcome: DLP-in-URL case, HTML hidden-comment payloads, or CI
wiring. Open a PR against `main`.
