# docker-ssh

Ubuntu 22.04 running as a lightweight VPS (like LXD/LXC) inside Docker: equipped with SSH, Tailscale, a web terminal (ttyd), and File Browser. Processes are managed by supervisord + tini, and all configurations are handled via environment variables.
- Source: https://github.com/hungrerovn/docker-ssh
- Docker Hub: https://hub.docker.com/r/hungrerovn/ubuntu

## Quick Start

Log in using an SSH key (recommended):

```bash
docker run -d --name vps \
  -e PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -p 2222:22 \
  hungrerovn/ubuntu:latest

```
Log in using a password:
```bash
docker run -d --name vps \
  -e SSH_PASSWORD='123' \
  -p 2222:22 \
  hungrerovn/ubuntu:latest

```
Enable all features:
```bash
docker run -d --name vps \
  -e SSH_USER=ubuntu \
  -e SSH_PASSWORD='123' \
  -e PUBLIC_KEY="ssh-ed25519 AAAA..." \
  -e TAILSCALE_AUTHKEY=tskey-auth-xxx \
  -e SSH_WEB=true \
  -e FILE_MANAGER=true \
  -e FILE_MANAGER_PASSWORD='Password@123' \
  -p 2222:22 -p 7681:7681 -p 8080:8080 \
  -v vps-home:/home/ubuntu \
  hungrerovn/ubuntu:latest

```
If passwords contain special characters (@, !, $...), remember to wrap them in single quotes '...'.
## Environment Variables
| Variable | Default | Description |
|---|---|---|
| SSH_USER | ubuntu | Name of the user to be created (passwordless sudo enabled) |
| SSH_PORT | 22 | Internal sshd port inside the container |
| PUBLIC_KEY | *(empty)* | SSH public key, written to the authorized_keys of both SSH_USER and root |
| SSH_PASSWORD | *(empty)* | Sets the password for SSH_USER and enables password-based SSH login |
| TAILSCALE_AUTHKEY | *(empty)* | Enables Tailscale (userspace networking, includes SOCKS5/HTTP proxy at localhost:1055) |
| SSH_WEB | false | Set to true or 1 to enable ttyd (web terminal). **Requires SSH_PASSWORD** |
| TTYD_PORT | 7681 | Port for ttyd |
| FILE_MANAGER | false | Set to true or 1 to enable File Browser. Requires FILE_MANAGER_PASSWORD or SSH_PASSWORD |
| FILE_MANAGER_PASSWORD | SSH_PASSWORD | File Browser password. File Browser has its own password policy (length, strength); if rejected, File Browser will not run, but SSH will still function properly |
| FILE_MANAGER_PORT | 8080 | Port for File Browser |
## Ports
| Port | Service |
|---|---|
| 22 | SSH |
| 7681 | ttyd, log in using SSH_USER / SSH_PASSWORD |
| 8080 | File Browser, root directory is /home/SSH_USER |
## Logs
View logs using docker logs <container_name>. Errors in optional components (such as File Browser) will not stop the container; they will only print a warning:
```bash
docker logs vps | grep '[warn]'

```
## Default Security
 * The root account has its password locked; root SSH login is restricted to keys only.
 * Password-based SSH login is **disabled** until SSH_PASSWORD is set.
 * ttyd and File Browser run over plain HTTP without TLS. It is recommended to access them exclusively via Tailscale or place them behind an HTTPS reverse proxy; do not expose them directly to the open Internet.
## Versions (Tags)
 * Version tags (v0.x, etc.) are fixed releases and **will never be overwritten**. Bug fixes will be published as new patch versions.
 * latest always points to the latest stable release and will change over time. Docker does not update containers automatically; run docker pull hungrerovn/ubuntu:latest to get the latest version.
## Notes
 * Tailscale runs in userspace, so **neither** --cap-add=NET_ADMIN **nor** /dev/net/tun is required.
 * To preserve data when deleting the container, mount a volume to /home/<SSH_USER>.
## Build from Source
```bash
git clone [https://github.com/hungrerovn/docker-ssh](https://github.com/hungrerovn/docker-ssh)
cd docker-ssh
docker build -t docker-ssh .

```
## License
MIT
