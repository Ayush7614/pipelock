# MCP Tool Policy Example

Runnable walkthrough for `mcp_tool_policy`: a **default-allow denylist** of tool
name and argument rules. Unmatched calls reach a benign local MCP decoy;
matched calls are blocked before egress.

This is different from the other MCP examples:

| Example | Attack surface |
|---------|----------------|
| `tool-response-injection` | Poisoned **tool response** body |
| `tool-poisoning-honeypot` | Poisoned **tools/list** description |
| **`mcp-tool-policy` (this)** | Operator **policy** on tool name / args |

## What This Demonstrates

| Check | What it proves |
|-------|----------------|
| Allow `echo` | Unmatched call reaches the decoy |
| Deny `run_shell` | Tool-name rule blocks |
| Deny `read_file` with `.ssh` path | Arg pattern + arg_key block |
| Allow small `transfer` / Deny large | `arg_number_gt` |
| Allow `reader` / Deny `admin` | `arg_value_in` |
| Deny long `write_note` | `arg_len_gt` |

## Prerequisites

- `pipelock` on `PATH`, or set `PIPELOCK_BIN`
- Bash 3.2+, Python 3

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
pipelock mcp proxy --config examples/mcp-tool-policy/pipelock.yaml -- \
  python3 examples/mcp-tool-policy/policy_decoy_server.py
```

Then send JSON-RPC lines on stdin (`initialize`, `tools/call`, …).

## Config Notes

`mcp_tool_policy` has no `action: allow` — “allow” means no rule matched.
Competing MCP scanning layers are disabled in this example so outcomes are
attributable to policy alone.

See `../../docs/configuration.md` (MCP Tool Policy).

## Contributing

Improvements welcome: `redirect`/`defer` cases, or HTTP upstream mode. Open a
PR against `main`.
