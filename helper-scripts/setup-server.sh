#!/bin/bash

# Define variables
key_dir="/tmp/ssh_keys"
mkdir -p "$key_dir"

# --- Function Definitions ---

update_system_and_install_tools() {
    echo "Updating system packages and installing security tools..."
    apt-get update && apt-get upgrade -y
    apt-get install ufw fail2ban curl software-properties-common -y
}

configure_firewall() {
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow $new_ssh_port/tcp
    ufw --force enable
}

secure_shared_memory() {
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
}

change_ssh_port() {
    new_ssh_port=$(shuf -i 10240-65535 -n 1)
    sed -i "/Port 22/c\Port $new_ssh_port" /etc/ssh/sshd_config
    systemctl restart sshd
}

setup_automatic_security_updates() {
    apt-get install unattended-upgrades apt-listchanges -y
    dpkg-reconfigure -plow unattended-upgrades
}

install_docker() {
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io -y
}

deploy_endlessh_tarpit() {
    docker run -d --name endlessh -p 22:2222 m13253/endlessh
}

generate_ssh_key() {
    ssh-keygen -b 4096 -t rsa -f "$key_dir/id_rsa" -N ""
    echo "SSH key generated at $key_dir/id_rsa"
}

append_key_to_authorized_keys() {
    cat "$key_dir/id_rsa.pub" >> ~/.ssh/authorized_keys
}

generate_otp() {
    echo $((RANDOM % 9999 + 1000))
}

start_otp_protected_web_server() {
    local otp=$(generate_otp)
    echo "Your One-Time Password (OTP) for accessing the web server is: $otp"
    echo "Access your SSH key at: http://$(hostname -I | cut -d' ' -f1):8000/"
    while :; do
        echo -ne "HTTP/1.0 200 OK\r\nContent-Length: $(wc -c <"$key_dir/id_rsa")\r\n\r\n"; cat "$key_dir/id_rsa" | nc -l -p 8000 -q 1 | grep --line-buffered "$otp" && break
    done
}

# --- Main Function ---

main() {
    update_system_and_install_tools
    secure_shared_memory
    setup_automatic_security_updates

    install_docker
    deploy_endlessh_tarpit

    change_ssh_port
    configure_firewall

    generate_ssh_key
    append_key_to_authorized_keys
    start_otp_protected_web_server
}

main