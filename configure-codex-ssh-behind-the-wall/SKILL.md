---
name: configure-codex-ssh-behind-the-wall
description: Configure SSH access from Codex or a student's local computer to an intranet server for course or lab use, especially behind restricted networks or proxy environments. Use when each student needs to fill a setup checklist with user_name, server HostName, SSH Port, VPN or jump host requirements, their own SSH key, Host alias codex-user_name, server User user_name, optional Codex auth.json copy, SSH remote port forwarding through the student's local proxy, and server-side Codex CLI verification.
---

# configure codex ssh behind the Wall

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

Require `user_name`, `server_host`, and `server_port`. Do not assume HostName or Port.

Derived values:

```text
Host alias: codex-user_name
HostName: server_host
User: user_name
Port: server_port
Remote default directory after login: the user's home directory
Local proxy candidate: local_proxy_host:local_proxy_port
```

Assume students connect from their own computers. Do not share one private key among students. Each student must generate a separate key pair and only submit or install the `.pub` public key.

## SSH Workflow

Set variables for examples:

```bash
user_name="REPLACE_WITH_USER_NAME"
server_host="REPLACE_WITH_SERVER_HOST"
server_port="REPLACE_WITH_SERVER_PORT"
host_alias="codex-${user_name}"
server_key_label="$(printf '%s' "${server_host}" | tr -c 'A-Za-z0-9' '_')"
key_path="${HOME}/.ssh/codex_${server_key_label}_${user_name}"
```

Check existing SSH files before writing:

```bash
ls -la ~/.ssh
test -f ~/.ssh/config && sed -n '1,220p' ~/.ssh/config
```

Generate a per-student key if needed:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f "${key_path}" -C "codex-${server_host}-${user_name}" -N ""
```

Add or update `~/.ssh/config`:

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

Install the public key when password login is available:

```bash
ssh-copy-id -i "${key_path}.pub" -p "${server_port}" "${user_name}@${server_host}"
```

If `ssh-copy-id` is not available, have the student send only this public key output:

```bash
cat "${key_path}.pub"
```

Append that public key line to the server user's `~/.ssh/authorized_keys` and enforce permissions:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Verify passwordless access:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 "${host_alias}" 'hostname; whoami; pwd; echo "$HOME"'
```

The bundled script verifies an SSH alias without prompting for a password:

```bash
bash /path/to/configure-codex-ssh-behind-the-wall/scripts/verify_ssh.sh codex-user_name
```

## Optional Codex Auth Copy

Only do this when the user explicitly asks to make the server use the same Codex login as the local computer. Treat `~/.codex/auth.json` as a sensitive credential. Do not print or paste its contents.

```bash
test -f ~/.codex/auth.json
ssh "${host_alias}" 'install -d -m 700 ~/.codex'
scp ~/.codex/auth.json "${host_alias}:~/.codex/auth.json"
ssh "${host_alias}" 'chmod 600 ~/.codex/auth.json'
ssh "${host_alias}" 'stat -c "%a %s %n" ~/.codex/auth.json'
```

Expected remote permissions are `600`. The remote path should be under that user's home directory.

## Optional Local Proxy Forwarding

Use this when the server must reach the internet through the local computer's proxy.

First tell the user to open their proxy/VPN client. Then confirm whether the local proxy is available at the checklist value, usually `127.0.0.1:7897`:

```bash
lsof -nP -iTCP:"${local_proxy_port:-7897}" -sTCP:LISTEN
curl -I --connect-timeout 8 -x "http://${local_proxy_host:-127.0.0.1}:${local_proxy_port:-7897}" https://api.openai.com
```

If `lsof` does not show a listener but `curl -x ...` works, treat the proxy address as confirmed. If both checks fail, stop and tell the user to confirm the local proxy address and port.

Start SSH remote port forwarding after the proxy is confirmed:

```bash
ssh -fN -o ExitOnForwardFailure=yes -R "${local_proxy_port}:127.0.0.1:${local_proxy_port}" "${host_alias}"
```

Confirm server-side listener and proxy access:

```bash
ssh "${host_alias}" "ss -ltnp 2>/dev/null | grep ${local_proxy_port} || true"
ssh "${host_alias}" "curl -I --connect-timeout 10 -x http://127.0.0.1:${local_proxy_port} https://api.openai.com"
```

Create a remote opt-in proxy environment file:

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

Replace `REPLACE_WITH_LOCAL_PROXY_PORT` with the confirmed proxy port before writing the file. On the server, use it with:

```bash
source ~/.codex/proxy.env
curl -I https://api.openai.com
```

The bundled script starts and verifies the tunnel:

```bash
bash /path/to/configure-codex-ssh-behind-the-wall/scripts/start_reverse_proxy.sh codex-user_name 7897
```

## Server-Side Codex CLI

Use this after SSH, auth copy, and proxy forwarding are working. Some shared servers expose Codex as an environment module:

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

If Codex opens with a `codex_apps` MCP timeout warning on a headless server, the CLI itself is usually still usable. Prefer disabling the `codex_apps` MCP block in the server's `~/.codex/config.toml` unless the user explicitly needs desktop app connectors.

The bundled script checks the remote module, proxy environment, and CLI version:

```bash
bash /path/to/configure-codex-ssh-behind-the-wall/scripts/verify_server_codex.sh codex-user_name
```

## Troubleshooting

- `Host key verification failed`: retry once with `ssh -o StrictHostKeyChecking=accept-new codex-user_name ...` after confirming server address and port.
- `Permission denied (publickey,...)`: install the student's public key, confirm `IdentityFile`, and check server-side `~/.ssh` permissions.
- `Operation timed out` or `No route to host`: confirm VPN, IP, port, and firewall rules.
- `Could not resolve hostname`: fix `HostName` or DNS.
- Proxy test fails: ask the user to open their proxy client and confirm the actual local HTTP/SOCKS port.
- `codex: command not found`: run `module avail` and `module load codex`; if absent, ask the server administrator to install or expose Codex.

## Safety Rules

- Never ask students to share private keys.
- Only share `.pub` public keys.
- Never ask students to share `~/.codex/auth.json` with each other.
- Keep proxy forwarding bound to `127.0.0.1` unless explicitly exposing it is intended.
- Treat `~/.codex/proxy.env` as opt-in. Do not automatically source it in shell startup files until the user confirms that behavior.
- Preserve existing `~/.ssh/config` content. Add a new `Host` block or edit the matching one deliberately.
