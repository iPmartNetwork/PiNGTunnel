#!/bin/bash

# ----------- COLOR CODES -----------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

function print_banner() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║   pingtunnel (esrrhs) Auto-Build & Network Tuner    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

function install_deps() {
    echo -e "${YELLOW}Installing build dependencies...${NC}"
    apt update -y
    apt install -y git curl wget build-essential ethtool
    if ! command -v go &>/dev/null; then
        wget https://go.dev/dl/go1.22.3.linux-amd64.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf go1.22.3.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        export PATH=$PATH:/usr/local/go/bin
    fi
    source /etc/profile
}

function build_pingtunnel() {
    echo -e "${YELLOW}Cloning and building latest esrrhs/pingtunnel from GitHub...${NC}"
    rm -rf /opt/pingtunnel
    git clone https://github.com/esrrhs/pingtunnel.git /opt/pingtunnel
    cd /opt/pingtunnel
    go build -o /usr/local/bin/pingtunnel .
    chmod +x /usr/local/bin/pingtunnel
    cd ~
}

function optimize_network() {
    echo -e "${YELLOW}Applying advanced network optimizations...${NC}"
    modprobe tcp_bbr
    if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null; then
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi

    cat << EOF > /etc/sysctl.d/99-pingtunnel-opt.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.core.optmem_max = 25165824
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_ecn = 1
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
fs.file-max = 1048576
EOF

    sysctl --system

    # Ulimit
    ulimit -n 1048576
    if ! grep -q "1048576" /etc/security/limits.conf; then
        echo "* soft nofile 1048576" >> /etc/security/limits.conf
        echo "* hard nofile 1048576" >> /etc/security/limits.conf
    fi

    echo -e "${YELLOW}Setting MTU to 1300 on all interfaces...${NC}"
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set dev $iface mtu 1300 2>/dev/null
        ethtool -K $iface gro off gso off tso off 2>/dev/null
        ethtool -C $iface rx-usecs 16 tx-usecs 16 adaptive-rx on adaptive-tx on 2>/dev/null
    done
}

function setup_ntp() {
    echo -e "${YELLOW}Syncing system time with NTP...${NC}"
    timedatectl set-ntp true
}

function create_systemd_service() {
    ROLE=$1
    PORT=$2
    REMOTE_IP=$3
    REMOTE_PORT=$4
    MTU=$5

    if [[ $ROLE == "server" ]]; then
        cat << EOF > /etc/systemd/system/pingtunnel.service
[Unit]
Description=pingtunnel Server (ICMP Tunnel)
After=network.target

[Service]
ExecStart=/usr/local/bin/pingtunnel -type server -l :${PORT} -key secret123 -mtu ${MTU}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    else
        cat << EOF > /etc/systemd/system/pingtunnel.service
[Unit]
Description=pingtunnel Client (ICMP Tunnel)
After=network.target

[Service]
ExecStart=/usr/local/bin/pingtunnel -type client -l 127.0.0.1:1080 -s ${REMOTE_IP}:${REMOTE_PORT} -key secret123 -mtu ${MTU}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable pingtunnel
    systemctl restart pingtunnel
}

# ------------- MAIN SCRIPT --------------

print_banner
install_deps
build_pingtunnel
optimize_network
setup_ntp

echo -e "${YELLOW}Do you want to run as (1) Server or (2) Client? [1/2]: ${NC}"
read ROLESEL
if [[ $ROLESEL == "1" ]]; then
    ROLE="server"
    read -p "Enter listen port for ICMP tunnel (default 8080): " PORT
    PORT=${PORT:-8080}
    MTU="1200"
    create_systemd_service $ROLE $PORT "" "" $MTU
    echo -e "${GREEN}pingtunnel Server running on port $PORT with MTU $MTU (ICMP)${NC}"
    echo -e "${GREEN}SOCKS5 proxy will NOT be available on server; only tunnel endpoint!${NC}"
else
    ROLE="client"
    read -p "Enter remote server IP: " REMOTE_IP
    read -p "Enter remote server port (default 8080): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-8080}
    MTU="1200"
    create_systemd_service $ROLE "" $REMOTE_IP $REMOTE_PORT $MTU
    echo -e "${GREEN}pingtunnel Client running; SOCKS5 proxy at 127.0.0.1:1080${NC}"
    echo -e "${GREEN}Connect your applications to 127.0.0.1:1080 for tunneling.${NC}"
fi

echo -e "${YELLOW}Status:${NC}"
systemctl status pingtunnel --no-pager

echo -e "${GREEN}All done! Please reboot your system for maximum effect.${NC}"
