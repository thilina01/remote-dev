# Use lightweight Alpine as the base image
FROM alpine:latest

# Install OpenVPN, OpenSSH server, and client
RUN apk --no-cache add \
    openvpn \
    openssh-server \
    openssh-client \
    sshpass

# Generate SSH host keys
RUN ssh-keygen -A

# Configure OpenSSH server
RUN mkdir /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Set environment variables for SSH and VPN
ENV VPN_CONFIG_PATH="/etc/openvpn/vpn-config.ovpn"

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH and web server ports
EXPOSE 22 7777 

# Set the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]




# echo -e "VPN_USERNAME\nVPN_PASSWORD**" | docker secret create vpn_password -
# docker build -t thilina01/remote-dev-vpn-ssh .
# docker run -d -p 2222:22 -p 8080:8080 --name remote-dev-vpn-ssh thilina01/remote-dev-vpn-ssh
# docker stack deploy -c docker-compose.yml remote-dev-stack

# sshpass -p "SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -N -L 0.0.0.0:2222:REMOTE_SSH_HOST:22 thilina@REMOTE_SSH_HOST &

#  ssh -v -p 2222 thilina@localhost
# ssh-keygen -R "[localhost]:2222"