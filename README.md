# Gleam Docs MCP

[![CI](https://github.com/JustAHobbyDev/gleam-docs-mcp/actions/workflows/test.yml/badge.svg)](https://github.com/JustAHobbyDev/gleam-docs-mcp/actions)
[![Gleam](https://img.shields.io/badge/Gleam-1.18.1-ffaff3)](https://gleam.run)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

A native Gleam MCP server for grounded compiler diagnostics and ecosystem
package discovery. It runs on the BEAM, communicates over stdio, and exposes a
small read-oriented tool set with explicit MCP safety annotations.

## Tools

| Tool | Description |
|---|---|
| `get_compiler_diagnostics` | Run `gleam check` in a local project and return its diagnostics |
| `list_dependencies` | Read dependencies and dev dependencies from `gleam.toml` |
| `list_local_modules` | Recursively list Gleam modules under `src/` |
| `gloogle_search` | Search Gloogle by name or type signature |
| `search_hex_packages` | Search Hex for Gleam packages |
| `get_package_releases` | List the 20 most recent releases for a Hex package |

All six tools are advertised as read-only, non-destructive, and idempotent.
The local tools require a directory containing `gleam.toml`. The ecosystem
tools are stateless and use TLS-verified HTTP requests with a 10-second timeout.

`gloogle_search` depends on the external `api.gloogle.run` service. If that
service is unavailable or returns an unexpected response, the tool returns an
explicit MCP error result rather than crashing the server.

## Install

The tested toolchain is Gleam 1.18.1, Erlang/OTP 29.0.5, and rebar3 3.27.0.

```sh
git clone https://github.com/JustAHobbyDev/gleam-docs-mcp.git
cd gleam-docs-mcp
gleam deps download
gleam test
```

### Codex

Add the server to `~/.codex/config.toml`, replacing the checkout path:

```toml
[mcp_servers.gleam-docs]
command = "mise"
args = ["exec", "-C", "/absolute/path/to/gleam-docs-mcp", "--", "gleam", "run", "--no-print-progress"]
enabled = true
```

### Other MCP clients

Clients that support stdio servers can run Gleam directly from the checkout:

```json
{
  "mcpServers": {
    "gleam-docs": {
      "command": "gleam",
      "args": ["run", "--no-print-progress"],
      "cwd": "/absolute/path/to/gleam-docs-mcp"
    }
  }
}
```

Restart the client after changing its MCP configuration.

## Safety and failure behavior

- Commands are launched with an executable and argument list, never through a
  shell. Project paths containing spaces or shell metacharacters remain data.
- `gleam check` has a 60-second timeout and a 64 KiB output ceiling.
- Compiler errors are successful diagnostic results because the compiler ran
  and answered the query. Missing projects, missing executables, timeouts, HTTP
  failures, and invalid tool arguments return `isError: true`.
- The server does not cache project state or remote API responses.
- This safe-core release deliberately does not format or write source files and
  does not execute user-provided Gleam snippets.

## Development

```sh
gleam format --check src test
gleam test
gleam run --no-print-progress
```

Tests cover MCP initialization and dispatch, tool schemas and annotations,
typed Hex/Gloogle fixtures, recursive project discovery, compiler execution,
shell-metacharacter paths, timeouts, and output truncation.

## License

Apache-2.0. See [LICENSE](LICENSE).
