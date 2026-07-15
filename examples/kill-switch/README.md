# Kill Switch Example

Runnable walkthrough for Pipelock’s emergency deny-all kill switch: traffic is
blocked while `/health` stays up so operators can tell “alive but denying.”

This example is fully local. A tiny echo HTTP server and pipelock both bind on
`127.0.0.1`. Activation uses a **sentinel file** (most CI-stable source).

## What This Demonstrates

| Check | What it proves |
|-------|----------------|
| Inactive baseline | `/fetch` reaches a local echo server |
| Sentinel activate | Creating the sentinel file yields HTTP 503 `kill_switch_active` |
| Health stays up | `/health` is still 200 with `kill_switch_active: true` |
| Sentinel clear | Removing the file restores fetch traffic |

## Prerequisites

- `pipelock` on `PATH`, or set `PIPELOCK_BIN` to your built binary
- Bash 3.2+, `curl`, and Python 3

```bash
make build
export PIPELOCK_BIN="$PWD/pipelock"
```

## Quick Verify

```bash
./verify.sh
```

Exit code `0` means all checks passed.

## Manual Try

Terminal 1:

```bash
pipelock run --config examples/kill-switch/pipelock.yaml
```

Update `kill_switch.sentinel_file` to a path you control first. Then:

```bash
# baseline (allowed when echo/SSRF allowlist is configured)
curl -sS -G --data-urlencode "url=http://127.0.0.1:ECHO_PORT/" \
  "http://127.0.0.1:8888/fetch"

# activate
touch /path/to/sentinel
curl -sS -G --data-urlencode "url=http://127.0.0.1:ECHO_PORT/" \
  "http://127.0.0.1:8888/fetch"
# expect HTTP 503 {"error":"kill_switch_active",...}

curl -sS "http://127.0.0.1:8888/health"
# expect kill_switch_active: true, status still healthy

# clear
rm /path/to/sentinel
```

## Config Notes

`kill_switch.enabled: true` is itself an activation **source**, not a master
toggle. Leave it `false` and use `sentinel_file` (or SIGUSR1 / API) for
operational deny-all. Keep `health_exempt: true` so health checks remain
reachable during an emergency stop.

See `../../docs/guides/health.md` and `../../docs/configuration.md` (Kill Switch).

## Contributing

Improvements welcome: SIGUSR1 case, admin API case, or CI wiring. Open a PR
against `main`.
