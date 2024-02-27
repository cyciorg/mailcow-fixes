#!/bin/bash

# Define global variables
key_dir="/tmp/ssh_keys"
new_ssh_port=$(shuf -i 1024-65535 -n 1)

# --- Function Definitions ---

update_system_and_install_tools() {
    echo "Updating system packages..."
    apt-get update && apt-get upgrade -y
    echo "Installing UFW and Fail2Ban..."
    apt-get install ufw fail2ban -y
}

configure_firewall() {
    echo "Configuring UFW..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow $new_ssh_port/tcp
    ufw --force enable
}

secure_shared_memory() {
    echo "Securing shared memory..."
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
}

change_ssh_port() {
    echo "Changing SSH port to $new_ssh_port..."
    sed -i "/^#Port 22/c\Port $new_ssh_port" /etc/ssh/sshd_config
    systemctl restart sshd
}

setup_automatic_security_updates() {
    echo "Setting up automatic security updates..."
    apt-get install unattended-upgrades apt-listchanges -y
    dpkg-reconfigure -plow unattended-upgrades
}

install_docker() {
    echo "Installing Docker..."
    apt-get install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install docker-ce -y
}

deploy_endlessh_tarpit() {
    echo "Deploying Endlessh SSH tarpit..."
    docker run -d --restart unless-stopped --name endlessh -p 22:2222 m13253/endlessh
}

generate_ssh_key() {
    echo "Generating SSH key..."
    ssh-keygen -b 4096 -t rsa -f "$key_dir/id_rsa" -N ""
    echo "SSH key generated at $key_dir/id_rsa"
}

append_key_to_authorized_keys() {
    cat "$key_dir/id_rsa.pub" >> ~/.ssh/authorized_keys
    echo "SSH public key added to authorized_keys."
}

generate_otp() {
    echo $((RANDOM % 9999 + 1000))
}

start_otp_protected_web_server() {
    local otp=$(generate_otp)
    echo "Starting temporary web server..."
    echo "Your OTP for accessing the web server is: $otp"
    while :; do
        { echo -ne "HTTP/1.0 200 OK\r\nContent-Length: $(wc -c <"$key_dir/id_rsa")\r\n\r\n"; cat "$key_dir/id_rsa"; } | nc -l -p 8000 -q 1 | grep --line-buffered "$otp" && break
    done
    echo "Temporary web server started. Access your SSH key at http://$(hostname -I | cut -d' ' -f1):8000/"
}

# --- Main Logic ---

main() {
    mkdir -p "$key_dir"

    update_system_and_install_tools
    configure_firewall
    secure_shared_memory
    change_ssh_port
    setup_automatic_security_updates
    install_docker
    deploy_endlessh_tarpit
    generate_ssh_key
    append_key_to_authorized_keys
    start_otp_protected_web_server

    echo "Setup Complete!"
    echo "New SSH Port: $new_ssh_port"
    echo "Remember to configure your SSH client to use the new port for connections."
    echo "Use the provided OTP to download your private SSH key."
}

main