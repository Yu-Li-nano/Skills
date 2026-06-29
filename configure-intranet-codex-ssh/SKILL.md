---
name: configure-intranet-codex-ssh
description: Configure SSH access from Codex or a student's local computer to an intranet server for course or lab use. Use when each student needs to fill a setup checklist with user_name, server HostName, SSH Port, VPN or jump host requirements, their own SSH key, Host alias codex-user_name, server User user_name, optional Codex auth.json copy, SSH remote port forwarding through the student's local proxy, and server-side Codex CLI verification.
---

# Configure Intranet Codex SSH

## Inputs

Start every run by showing this checklist and asking the user to fill it in before making changes:

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

Require `user_name`, `server_host`, and `server_port`. Do not assume HostName or Port. `user_name` is the student's server account name and drives the SSH alias, remote user, and paths.

Derived values:

```text
Host alias: codex-user_name
HostName: server_host
User: user_name
Port: server_port
VPN: needs_vpn
Jump host: jump_host
Remote default directory after login: the user's home directory
Local proxy candidate: local_proxy_host:local_proxy_port
```

For a user named `alice`, the host alias is `codex-alice`, the SSH user is `alice`, and the key path should include both a sanitized server label and the username, for example `~/.ssh/codex_example_edu_alice`.

Assume students connect from their own computers. Do not share one private key among students. Each student must generate a separate key pair and only submit or install the `.pub` public key.

## SSH Workflow

1. Set local variables for examples:

```bash
user_name="REPLACE_WITH_USER_NAME"
server_host="REPLACE_WITH_SERVER_HOST"
server_port="REPLACE_WITH_SERVER_PORT"
host_alias="codex-${user_name}"
server_key_label="$(printf '%s' "${server_host}" | tr -c 'A-Za-z0-9' '_')"
key_path="${HOME}/.ssh/codex_${server_key_label}_${user_name}"
```

2. Check for existing SSH material before writing:

```bash
ls -la ~/.ssh
test -f ~/.ssh/config && sed -n '1,220p' ~/.ssh/config
```

3. Generate a per-student key if one does not already exist:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f "${key_path}" -C "codex-${server_host}-${user_name}" -N ""
```

4. Add or update the SSH config entry. Replace `user_name`, `server_host`, `server_port`, and the key path before writing:

```sshconfig
Host codex-user_name
  HostName server_host
  User user_name
  Port server_port
  IdentityFile ~/.ssh/codex_server_label_user_name
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

If a jump host is required, add `ProxyJump jump-user@jump-host` inside the same `Host` block.

5. Install the public key on the server. Prefer `ssh-copy-id` when password login is available:

```bash
ssh-copy-id -i "${key_path}.pub" -p "${server_port}" "${user_name}@${server_host}"
```

If `ssh-copy-id` is not available, have the student send only:

```bash
cat "${key_path}.pub"
```

Then append that single public-key line to the server user's `~/.ssh/authorized_keys` and enforce permissions:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

6. Verify passwordless access:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 "${host_alias}" 'hostname; whoami; pwd; echo "$HOME"'
```

A successful verification should show the expected `user_name` and a home directory for that user.

The bundled `scripts/verify_ssh.sh` validates an SSH alias without prompting for a password:

```bash
bash /path/to/configure-intranet-codex-ssh/scripts/verify_ssh.sh codex-user_name
```

## Optional Codex Auth Copy

Only do this when the user explicitly asks to make the server use the same Codex login as the local computer. Treat `~/.codex/auth.json` as a sensitive credential. Do not print or paste its contents.

Copy the local Codex auth file to the same user's server account:

```bash
test -f ~/.codex/auth.json
ssh "${host_alias}" 'install -d -m 700 ~/.codex'
scp ~/.codex/auth.json "${host_alias}:~/.codex/auth.json"
ssh "${host_alias}" 'chmod 600 ~/.codex/auth.json'
ssh "${host_alias}" 'stat -c "%a %s %n" ~/.codex/auth.json'
```

Expected remote permissions are `600`. The remote path should be under that user's home directory, normally `~/.codex/auth.json`.

## Optional Local Proxy Forwarding

Use this when the user asks to let the server reach the internet through the local computer's proxy.

First tell the user to open their proxy/VPN client. Then confirm whether the local proxy is available at the checklist value, usually `127.0.0.1:7897`.

Search and test locally:

```bash
lsof -nP -iTCP:"${local_proxy_port:-7897}" -sTCP:LISTEN
curl -I --connect-timeout 8 -x "http://${local_proxy_host:-127.0.0.1}:${local_proxy_port:-7897}" https://api.openai.com
```

If `lsof` does not show a listener but `curl -x ...` works, treat the proxy address as confirmed. Some proxy clients do not appear cleanly in `lsof`.

If both checks fail, stop and tell the user to confirm the local proxy address and port in their proxy client before continuing. Do not guess another port unless the user asks you to search common ports.

Start SSH remote port forwarding after the proxy is confirmed:

```bash
ssh -fN -o ExitOnForwardFailure=yes -R "${local_proxy_port}:127.0.0.1:${local_proxy_port}" "${host_alias}"
```

This makes the proxy port on the server forward back to the same port on the student's local computer. Confirm the server-side listener and proxy access:

```bash
ssh "${host_alias}" "ss -ltnp 2>/dev/null | grep ${local_proxy_port} || true"
ssh "${host_alias}" "curl -I --connect-timeout 10 -x http://127.0.0.1:${local_proxy_port} https://api.openai.com"
```

Create a remote environment file so commands can opt into the proxy without changing every shell by default:

```bash
ssh "${host_alias}" 'install -d -m 700 ~/.codex && cat > ~/.codex/proxy.env <<'"'"'EOF'"'"'
export http_proxy=http://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
export https_proxy=http://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
export HTTP_PROXY=http://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
export HTTPS_PROXY=http://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
export all_proxy=socks5h://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
export ALL_PROXY=socks5h://127.0.0.1:REPLACE_WITH_LOCAL_PROXY_PORT
EOF
chmod 600 ~/.codex/proxy.env'
```

Replace `REPLACE_WITH_LOCAL_PROXY_PORT` with the confirmed proxy port before writing the file.

Use it on the server with:

```bash
source ~/.codex/proxy.env
curl -I https://api.openai.com
```

The bundled `scripts/start_reverse_proxy.sh` prompts the user to open their proxy, verifies the provided local proxy port, starts the tunnel, and checks the server-side proxy:

```bash
bash /path/to/configure-intranet-codex-ssh/scripts/start_reverse_proxy.sh codex-user_name 7897
```

## Server-Side Codex CLI

Use this after SSH, auth copy, and proxy forwarding are working. On the tested server, Codex is installed as an environment module:

```bash
module avail
module load codex
codex --version
```

For a full server-side check:

```bash
module load codex
source ~/.codex/proxy.env
codex --version
curl -I https://api.openai.com
```

Then start Codex from the target project directory:

```bash
cd /path/to/project
module load codex
source ~/.codex/proxy.env
codex
```

If Codex opens with a warning like this, the CLI itself is still usable:

```text
MCP client for `codex_apps` timed out after 30 seconds
MCP startup incomplete (failed: codex_apps)
```

On a headless server, `codex_apps` is usually a desktop-app connector and is not required for normal CLI coding tasks. Prefer disabling the `codex_apps` MCP block in `~/.codex/config.toml` on the server. If the user explicitly needs it, add or increase `startup_timeout_sec` under `[mcp_servers.codex_apps]`, but increasing the timeout may only delay the same failure on servers without the matching desktop connector.

The bundled `scripts/verify_server_codex.sh` checks the remote module, proxy environment, and CLI version:

```bash
bash /path/to/configure-intranet-codex-ssh/scripts/verify_server_codex.sh codex-user_name
```

## Troubleshooting

- `Host key verification failed`: retry once with `ssh -o StrictHostKeyChecking=accept-new codex-user_name ...` after confirming the server address and port are correct.
- `Permission denied (publickey,...)`: install the student's public key into the target server account, confirm `IdentityFile`, and check `~/.ssh` permissions on the server.
- `Operation timed out` or `No route to host`: confirm network/VPN, IP, port, and firewall rules.
- `Could not resolve hostname`: fix the `HostName` value or DNS.
- Password prompt appears during verification: the key is not being used or not accepted; rerun with `ssh -v codex-user_name` only if the normal checks are insufficient.
- Proxy test fails on the checklist proxy address: tell the user to open their proxy client and confirm the actual local HTTP/SOCKS port.
- `codex_apps` MCP timeout in server Codex: ignore it for ordinary CLI use, or remove/comment the `[mcp_servers.codex_apps]` block from the server's `~/.codex/config.toml`.
- `codex: command not found`: run `module avail` and `module load codex`; if absent, ask the server administrator to install or expose the Codex module.

## Safety Rules

- Never ask students to share private keys such as `~/.ssh/codex_server_label_user_name`.
- Only share `.pub` public keys.
- Never ask students to share `~/.codex/auth.json` with each other. Copy it only for the same user's own server account when explicitly requested.
- Keep proxy forwarding bound to `127.0.0.1` unless the instructor explicitly wants to expose it to other users on the server.
- Treat `~/.codex/proxy.env` as an opt-in environment file. Do not automatically source it in shell startup files until the user confirms the proxy should affect every login shell.
- Avoid defaulting to `root`; use the assigned course account unless the instructor explicitly chooses otherwise.
- Preserve existing `~/.ssh/config` content. Add a new `Host` block or edit the matching one deliberately.
