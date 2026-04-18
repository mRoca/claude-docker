# claude-docker

Run [Claude Code](https://github.com/anthropics/claude-code) with all permissions inside a Docker container — better than the /sandbox mode.

Why? **Because I don't want to grant a new permission every single minute, but I also don't want Claude Code to have access to my entire system.**

Claude Code is an AI coding assistant that runs in your terminal. It can read, write, and execute code on your machine.
That's powerful, but it means a mistake could affect your whole system — install a broken package, overwrite a config file, remove your home directory, etc.

This project wraps Claude Code inside a Docker container: Claude still works on your real project files, but everything else (your system, your credentials, your other projects) stays isolated.
Think of it as giving Claude its own workspace where it can do its job without being able to break anything outside of it.

- **Mounts your project directory** so Claude reads and edits your real files
- **Shares `~/.claude` config** so authentication works out of the box
- **Runs as your UID/GID** so file ownership stays correct
- **Ephemeral container** — nothing persists outside your project and config directories
- **Full dev toolset** included (git, gh, ripgrep, python3, build-essential, …)
- **Auto token refresh** — detects expiring OAuth tokens before launch and refreshes them on the host

## How it compares

Claude Code has built-in isolation options: [`/sandbox`](https://code.claude.com/docs/en/sandboxing) wraps bash commands with OS-level restrictions but leaves file tools (Read/Edit/Write) unsandboxed and a lot of permissions to give,
and the official [devcontainer](https://code.claude.com/docs/en/devcontainer) provides full container isolation with network firewalling but requires VS Code and more setup.

`claude-docker` is the simplest option — a single Dockerfile and a bash wrapper — where everything runs inside the container and nothing outside the mounted directories exists at all.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- An Anthropic API key or a Claude Code account (`~/.claude` directory)

## Quick start

```bash
git clone https://github.com/mroca/claude-docker.git
cd claude-docker
```

To run `claude-docker` from any directory, symlink it into your `PATH`:

```bash
# If ~/.local/bin is in your PATH (check with: echo "$PATH" | grep -q ~/.local/bin && echo yes)
ln -s "$(pwd)/claude-docker" ~/.local/bin/claude-docker

# Otherwise, use /usr/local/bin (requires sudo)
sudo ln -s "$(pwd)/claude-docker" /usr/local/bin/claude-docker
```

## Usage

```bash
# Launch Claude in the current directory
claude-docker

# Pass any argument through to claude
claude-docker --version
claude-docker --model sonnet "explain this codebase"

# Force rebuild the image (e.g. after updating the repo or the Dockerfile)
claude-docker --build
```

`--build` rebuilds the image and exits. All other arguments are forwarded directly to `claude`.

## Configuration

Copy `claude-docker.env.dist` to `claude-docker.env` (gitignored) and uncomment the options you want:

```bash
cp claude-docker.env.dist claude-docker.env
```

| Variable | Default | Description |
|---|---|---|
| `CLIPBOARD_FORWARDING` | `false` | Forward the display server socket so Ctrl+V image paste works inside the container. See the security note in the config file. |

## Authentication

The wrapper supports two methods:

| Method | How |
|---|---|
| **OAuth (recommended)** | Run `claude` or `claude-docker` once — it opens a browser (or ask you doing it) for OAuth login and stores the session in `~/.claude`. The wrapper mounts this directory into the container automatically. No API key needed. |
| **OAuth token** | Set `CLAUDE_CODE_OAUTH_TOKEN` — passed through to the container when present. Useful in CI or headless environments where browser login isn't possible. Create it with `claude setup-token` |
| **API key** | Set `ANTHROPIC_API_KEY` — it is passed through to the container when present. |

## Security considerations

- **`~/.claude` is fully mounted**: the entire `~/.claude` directory is shared with the container. This includes credentials, settings, and memory/project data from **all your projects** — not just the one you're working on. Claude inside the container could read conversation history, CLAUDE.md files, or cached context from other repositories.
- **`--dangerously-skip-permissions`** is enabled in the entrypoint. This means Claude can read, write, and execute anything the container can reach — including your mounted project directory. The Docker boundary provides isolation from the rest of your host, but **any file you mount is fully accessible**.
- **Git history is visible**: your `.git` directory is part of the mounted project, so Claude can read the full commit history, diffs, and author info. However, **no host SSH keys or git credentials are shared** — the container cannot `git push`, `git pull` from private remotes, or delete remote branches.
- **Mount scope**: only your current working directory and `~/.claude` are mounted. Do not add broad mounts (e.g. `-v /:/host`) without understanding the implications.
- **Network access**: the container has unrestricted network access. Claude can make outbound HTTP requests, install packages, etc.
- **API key**: if you use `ANTHROPIC_API_KEY`, it is visible inside the container. Do not publish images built with a key baked in.
- **File ownership**: the container runs as your host UID/GID, so any file Claude creates or modifies will be owned by you — but also means it has the same filesystem permissions you do within the mounted directories.

## What's in the image

| Category | Tools |
|---|---|
| Base | node:22 |
| VCS | git, gh (GitHub CLI) |
| Shell utilities | curl, wget, jq, fzf, bat, fd, tree, less, unzip, zip |
| Search | ripgrep |
| Editors | vim |
| System | htop, lsof, procps, psmisc |
| Network | netcat, dnsutils, ping |
| Clipboard | xclip (X11), wl-clipboard (Wayland) |
| Python | python3, pip, venv |
| Build | build-essential |
| SSH | openssh-client |
| AI | claude (official installer) |

## License

MIT
