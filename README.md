# Skills

First, set up Codex CLI. Common installation options include the official installer or documentation, Homebrew, npm, and server-side modules.

## Install Codex CLI

Choose the method that matches your environment:

- Official installer or documentation: follow the current Codex CLI installation instructions from OpenAI for your operating system.
- Homebrew: install through the Homebrew formula or tap available for your environment, then verify with `codex --version`.
- npm: install the CLI package with npm, then verify with `codex --version`.
- module: on shared servers or clusters, run `module avail`, then `module load codex`, then `codex --version`.

Example check:

```bash
codex --version
```

For module-based environments:

```bash
module avail
module load codex
codex --version
```

## Available Skills

### configure codex ssh behind the Wall

Configure SSH access from a student's local computer to an intranet server for Codex CLI use, including optional proxy forwarding when the server needs to reach the internet through the student's local proxy.

Skill folder:

```text
configure-codex-ssh-behind-the-wall
```

This skill helps with:

- collecting the required setup checklist before making changes
- generating a per-user SSH key
- creating a `codex-user_name` SSH host alias
- installing the public key on the server
- copying the user's own `~/.codex/auth.json` to their own server account when requested
- starting SSH remote port forwarding so the server can use the student's local proxy
- verifying the server-side Codex CLI module

## Installation

Copy the skill folder into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
cp -R configure-codex-ssh-behind-the-wall ~/.codex/skills/
```

Then restart Codex or start a new Codex session so the skill can be discovered.

## Usage

Ask Codex to use the skill:

```text
Use the configure-codex-ssh-behind-the-wall skill to help me set up Codex SSH access to my intranet server.
```

The skill starts by asking for this checklist:

```text
user_name:
server_host:
server_port:
needs_vpn: yes/no
jump_host: none or user@host
local_proxy_host: 127.0.0.1
local_proxy_port: 7897
copy_codex_auth_json: yes/no
verify_server_codex_module: yes/no
```

Required fields are `user_name`, `server_host`, and `server_port`. The generated SSH alias is always:

```text
codex-user_name
```

For example, if `user_name` is `alice`, the SSH alias is:

```text
codex-alice
```

## Helper Scripts

After installing the skill, helper scripts are available under:

```text
~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/
```

Verify SSH:

```bash
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/verify_ssh.sh codex-user_name
```

Start reverse proxy forwarding:

```bash
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/start_reverse_proxy.sh codex-user_name 7897
```

Verify server-side Codex CLI:

```bash
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/verify_server_codex.sh codex-user_name
```

## Safety Notes

Do not share private keys. Only share `.pub` public keys.

Do not share `~/.codex/auth.json` between users. Copy it only to the same user's own server account when explicitly requested.

Keep proxy forwarding bound to `127.0.0.1` unless you intentionally want to expose the proxy to other users on the server.
