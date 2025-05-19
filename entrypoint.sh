#!/bin/sh

# Debug VPN credentials
# echo "Debug: Printing VPN credentials:"
# cat /run/secrets/vpn_password

# Copy and secure the VPN password
cp /run/secrets/vpn_password /tmp/vpn_password
chmod 600 /tmp/vpn_password

# Ensure TUN device exists
if [ ! -c /dev/net/tun ]; then
    echo "Creating TUN device..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
fi

# Create SSH user if not already created
if ! id "$SSH_USER" >/dev/null 2>&1; then
    echo "Creating SSH user $SSH_USER..."
    adduser -D -s /bin/sh "$SSH_USER"
    echo "$SSH_USER:$SSH_PASSWORD" | chpasswd
fi

# Start OpenVPN
echo "Starting OpenVPN..."
openvpn --config "${VPN_CONFIG_PATH}" --auth-user-pass /tmp/vpn_password --auth-nocache --verb 3 &

# Wait for VPN to establish
echo "Waiting for VPN connection to establish..."
for i in $(seq 1 30); do
    if ip link show tun0 > /dev/null 2>&1; then
        echo "VPN connection established."
        sleep 2
        break
    fi
    echo "VPN not ready, retrying... ($i/30)"
    sleep 2
done

# Check if VPN is ready
if ! ip link show tun0 > /dev/null 2>&1; then
    echo "VPN connection failed. Exiting."
    exit 1
fi

# Wait for remote SSH server to be reachable
echo "Checking remote SSH server availability..."
for i in $(seq 1 30); do
    if nc -z -w5 "$REMOTE_SSH_HOST" "$REMOTE_SSH_PORT"; then
        echo "Remote SSH server is reachable."
        sleep 3
        break
    fi
    echo "Remote SSH server not reachable, retrying... ($i/30)"
    sleep 2
done

# Check if remote SSH server is ready
if ! nc -z -w5 "$REMOTE_SSH_HOST" "$REMOTE_SSH_PORT"; then
    echo "Remote SSH server connection failed. Exiting."
    exit 1
fi

# Bind remote server's SSH to container's 2222
echo "Setting up SSH forwarding to remote server..."
sshpass -p "${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no -N -L 0.0.0.0:2222:"${REMOTE_SSH_HOST}:${REMOTE_SSH_PORT}" "${SSH_USER}@${REMOTE_SSH_HOST}" &

# Bind remote server's Code Server to container's 7777
if [ -n "$REMOTE_CODE_SERVER_HOST" ] && [ -n "$REMOTE_CODE_SERVER_PORT" ]; then
    echo "Setting up Code Server forwarding..."
    sshpass -p "${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no -N -L 0.0.0.0:7777:"${REMOTE_CODE_SERVER_HOST}:${REMOTE_CODE_SERVER_PORT}" "${SSH_USER}@${REMOTE_CODE_SERVER_HOST}" &
else
    echo "Skipping Code Server forwarding: REMOTE_CODE_SERVER_HOST or REMOTE_CODE_SERVER_PORT not set."
fi

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd -D
