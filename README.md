# Available Skills

# [Configure codex ssh behind the Wall](/configure-codex-ssh-behind-the-wall)

This skill helps users configure Codex CLI on a remote SSH server when the server is behind the Wall or a local proxy setup.

It is designed for course and lab environments where each user has their own server account and needs a repeatable setup flow for SSH access, Codex authentication, proxy forwarding, and server-side Codex CLI verification.

## Install Codex CLI

First, set up Codex CLI. Common installation options include the official installer, Homebrew, or npm.

Verify the installation with:

```
codex --version
```

## What This Skill Does

The skill walks Codex through:

- collecting the required setup checklist before making changes
- generating a per-user SSH key
- creating a `codex-user_name` SSH host alias
- installing the public key on the server
- copying the user's own `~/.codex/auth.json` to their own server account when requested
- starting SSH remote port forwarding so the server can use the user's local proxy
- verifying the server-side Codex CLI module

Skill folder:

```
configure-codex-ssh-behind-the-wall
```

## Installation

Copy the skill folder into your Codex skills directory:

```
mkdir -p ~/.codex/skills
cp -R configure-codex-ssh-behind-the-wall ~/.codex/skills/
```

Then restart Codex or start a new Codex session so the skill can be discovered.

## Usage

Ask Codex to use the skill:

```
Use the configure-codex-ssh-behind-the-wall skill to help me set up Codex SSH access to my intranet server.
```

The skill starts by asking for this checklist:

```
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

Required fields are `user_name`, `server_host`, and `server_port`.

The generated SSH alias is:

```
codex-user_name
```

For example, if `user_name` is `alice`, the SSH alias is:

```
codex-alice
```

## Helper Scripts

After installing the skill, helper scripts are available under:

```
~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/
```

Verify SSH:

```
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/verify_ssh.sh codex-user_name
```

Start reverse proxy forwarding:

```
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/start_reverse_proxy.sh codex-user_name 7897
```

Verify server-side Codex CLI:

```
bash ~/.codex/skills/configure-codex-ssh-behind-the-wall/scripts/verify_server_codex.sh codex-user_name
```

## Safety Notes

Do not share private keys. Only share `.pub` public keys.

Do not share `~/.codex/auth.json` between users. Copy it only to the same user's own server account when explicitly requested.

Keep proxy forwarding bound to `127.0.0.1` unless you intentionally want to expose the proxy to other users on the server.
