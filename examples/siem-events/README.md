# SIEM Events Example

Runnable walkthrough for Pipelock **event emission** to a SIEM-style webhook:
blocked requests produce JSON events that a local collector can assert.

This is different from `examples/prometheus/` (Alertmanager rules only) and
`examples/kill-switch/` (deny-all). Here the focus is `emit.webhook` delivery.

Fully offline: local webhook sink + `/fetch` against a metadata IP (core SSRF).

## What This Demonstrates

| Check | What it proves |
|-------|----------------|
| Clean fetch | No `blocked` event for an allowed request |
| SSRF block | `/fetch` to `169.254.169.254` returns 403 |
| Webhook emit | Collector receives `type=blocked`, `severity=warn`, `scanner=ssrf` |

## Prerequisites

- `pipelock` on `PATH`, or set `PIPELOCK_BIN`
- Bash 3.2+, `curl`, Python 3

```bash
make build
export PIPELOCK_BIN="$PWD/pipelock"
```

## Quick Verify

From the repository root:

```bash
./examples/siem-events/verify.sh
```

Or from this directory: `./verify.sh` (with `PIPELOCK_BIN` set if needed).

## Manual Try

Start a collector that accepts `POST /events`, point `emit.webhook.url` at it,
then:

```bash
"$PIPELOCK_BIN" run --config examples/siem-events/pipelock.yaml
curl -sS -G --data-urlencode "url=http://169.254.169.254/latest/meta-data/" \
  "http://127.0.0.1:8888/fetch"
```

If `pipelock` is already on your `PATH`, you can use `pipelock` instead of `"$PIPELOCK_BIN"`.

## Config Notes

`emit` has no file sink — use `webhook`, `syslog`, or `otlp`. `allowed` events
are local-only and never reach the webhook regardless of `min_severity`.

See `../../docs/guides/siem-integration.md`.

## Contributing

Improvements welcome: syslog UDP case, DLP block with URL redaction, or CEF
format. Open a PR against `main`.
