#!/bin/bash
set -e

SSH_USER=${SSH_USER:-ubuntu}
SSH_PORT=${SSH_PORT:-22}
TTYD_PORT=${TTYD_PORT:-7681}
FILE_MANAGER_PORT=${FILE_MANAGER_PORT:-8080}

if ! id "$SSH_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$SSH_USER"
    usermod -aG sudo "$SSH_USER"
fi

passwd -l root >/dev/null 2>&1 || true
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SSH_USER"
chmod 440 "/etc/sudoers.d/$SSH_USER"

if [ -n "$PUBLIC_KEY" ]; then
    passwd -l "$SSH_USER" >/dev/null 2>&1 || true
    mkdir -p /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    mkdir -p "/home/$SSH_USER/.ssh"
    echo "$PUBLIC_KEY" > "/home/$SSH_USER/.ssh/authorized_keys"
    chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh"
    chmod 700 "/home/$SSH_USER/.ssh"
    chmod 600 "/home/$SSH_USER/.ssh/authorized_keys"
fi

if [ -n "$TAILSCALE_AUTHKEY" ]; then
cat <<EOF > /etc/supervisor/conf.d/tailscale.conf
[program:tailscaled]
command=/usr/sbin/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock
priority=5
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:tailscale]
command=/usr/bin/tailscale up --authkey=${TAILSCALE_AUTHKEY} --ssh
priority=10
autostart=true
autorestart=false
startretries=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
fi

sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config

if [ -n "$SSH_PASSWORD" ]; then
    echo "$SSH_USER:$SSH_PASSWORD" | chpasswd
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

if [ "$SSH_WEB" = "true" ] || [ "$SSH_WEB" = "1" ]; then
if [ -n "$SSH_PASSWORD" ]; then
cat <<EOF > /etc/supervisor/conf.d/ttyd.conf
[program:ttyd]
command=ttyd --port ${TTYD_PORT} /bin/login
priority=20
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
fi
fi

if [ "$FILE_MANAGER" = "true" ] || [ "$FILE_MANAGER" = "1" ]; then
    set +e
    rm -f /etc/supervisor/conf.d/filebrowser.conf
    FM_PASS="${FILE_MANAGER_PASSWORD:-$SSH_PASSWORD}"
    FM_DB=/var/lib/filebrowser/filebrowser.db
    FM_OK=0

    if [ -z "$FM_PASS" ]; then
        echo "[warn] File Browser: FILE_MANAGER_PASSWORD or SSH_PASSWORD is required, skipping"
    elif ! FM_OUT=$(mkdir -p /var/lib/filebrowser 2>&1); then
        echo "[warn] File Browser: cannot create data directory: $FM_OUT"
    elif [ ! -f "$FM_DB" ] && ! FM_OUT=$(filebrowser config init --database "$FM_DB" 2>&1); then
        echo "[warn] File Browser: config init failed: $FM_OUT"
    else
        if filebrowser users find "$SSH_USER" --database "$FM_DB" >/dev/null 2>&1; then
            FM_ACTION=update
            FM_OUT=$(filebrowser users update "$SSH_USER" --password "$FM_PASS" --database "$FM_DB" 2>&1)
        else
            FM_ACTION=add
            FM_OUT=$(filebrowser users add "$SSH_USER" "$FM_PASS" --perm.admin --database "$FM_DB" 2>&1)
        fi
        if [ $? -eq 0 ]; then
            FM_OK=1
        else
            echo "[warn] File Browser: users $FM_ACTION failed: $FM_OUT"
        fi
    fi

    if [ "$FM_OK" = "1" ]; then
cat <<EOF > /etc/supervisor/conf.d/filebrowser.conf
[program:filebrowser]
command=filebrowser --address 0.0.0.0 --port ${FILE_MANAGER_PORT} --root /home/${SSH_USER} --database ${FM_DB}
priority=25
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
    else
        echo "[warn] File Browser is disabled, SSH is not affected"
    fi
    set -e
fi

mkdir -p /run/sshd /var/lib/tailscale /var/run/tailscale
ssh-keygen -A
exec supervisord
