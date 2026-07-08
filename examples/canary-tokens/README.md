# Canary Tokens Example

Runnable walkthrough for Pipelock canary tokens: synthetic secrets injected into
an agent environment that trip an alarm if exfiltrated in outbound traffic.

This example uses the **offline scanner** (`pipelock check --url`) — no running
proxy required.

## What This Demonstrates

| Check | What it proves |
|-------|----------------|
| `pipelock canary` | Prints a paste-ready `canary_tokens` YAML snippet |
| Direct match | Canary value embedded in a URL path is blocked |
| Clean URL | URLs without the canary are allowed |
| Base64 encoding | Encoded canary still detected |
| Separator split | Canary split across subdomain labels still detected |

## Prerequisites

- `pipelock` on `PATH`, or set `PIPELOCK_BIN` to your built binary
- Bash 3.2+ and Python 3

Build from the repo root if needed:

```bash
make build
export PIPELOCK_BIN="$PWD/pipelock"
```

## Quick Verify

From this directory:

```bash
./verify.sh
```

Exit code `0` means all checks passed. The script:

1. Generates a unique canary value at runtime (never committed to the repo)
2. Writes a temp config from `pipelock.yaml`
3. Runs `pipelock canary` snippet checks
4. Confirms direct, base64, and split canary detections block
5. Confirms a clean URL is allowed

## Generate a Snippet

Default snippet (value references an env var placeholder):

```bash
pipelock canary --name demo_canary --env-var DEMO_CANARY_VALUE
```

Paste the output into your `pipelock.yaml`, then inject the real value into the
agent environment:

```bash
export DEMO_CANARY_VALUE="canary-$(openssl rand -hex 16)"
pipelock run --config pipelock.yaml --listen 127.0.0.1:8888
```

For local testing only, print the literal value:

```bash
pipelock canary --name demo_canary --env-var DEMO_CANARY_VALUE --literal
# warning: --literal prints the canary token value to stdout
```

## Example Config

`pipelock.yaml` is a template. `verify.sh` substitutes a runtime-generated value
in place of `${DEMO_CANARY_VALUE}`.

```yaml
canary_tokens:
  enabled: true
  tokens:
    - name: demo_canary
      value: "<runtime-generated in verify.sh>"
      env_var: DEMO_CANARY_VALUE
```

Unlike regex DLP, canary matching is **exact** after normalization — no false
positives from substring collisions.

See `docs/guides/canary-tokens.md` for normalization passes and deployment
patterns.

## Manual Check

After exporting a canary value and updating config:

```bash
pipelock check --config pipelock.yaml \
  --url "https://collector.vendor.example/?token=$DEMO_CANARY_VALUE"
```

Expected: `BLOCKED` with pattern `Canary Token (demo_canary)`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Validation error on config | Token values must be unique and at least 8 characters |
| Canary not detected | Confirm `canary_tokens.enabled: true` and value matches env |
| False sense of safety | Canary proves exfil of *that* value; still configure DLP |

## Security Note

Canary values are intentional traps. Treat generated literals like secrets in
logs and shell history.

## Contributing

Improvements welcome: env-var resolution docs, live-proxy verify path, or CI
wiring. Open a PR against `main`.
