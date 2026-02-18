# claude-sandbox

Run `claude` inside a persistent Docker container with build toolchains (Go, Node, C/C++).

## Setup

Add an alias to your shell config (`~/.bashrc`, `~/.zshrc`, etc.):

```sh
alias claude='/path/to/claude-sandbox/claude-sandbox.sh'
```

To bypass the alias and run the host `claude` directly:

```sh
\claude
# or
command claude
```

## How it works

On first invocation, the script builds a Docker image and creates a persistent container. Subsequent calls reuse the running container via `docker exec` — no startup overhead.

All arguments are forwarded to `claude --dangerously-skip-permissions` inside the container.

## Maintenance commands

```sh
claude-sandbox.sh --sandbox-status    # Show container state
claude-sandbox.sh --sandbox-stop      # Stop the container
claude-sandbox.sh --sandbox-rebuild   # Force image rebuild + container recreation
```

## Limitations

- Only the current working directory and `~/.claude` (for authentication) are mounted into the container — the rest of your home directory is not accessible.
