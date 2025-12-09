#!/bin/bash

# MGHOSTX Installer for Arch Linux

set -e

echo -e "\033[1;36m"
cat << "EOF"
███╗   ███╗ ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗██╗  ██╗
████╗ ████║██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝╚██╗██╔╝
██╔████╔██║██║  ███╗███████║██║   ██║███████╗   ██║    ╚███╔╝ 
██║╚██╔╝██║██║   ██║██╔══██║██║   ██║╚════██║   ██║    ██╔██╗ 
██║ ╚═╝ ██║╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██╔╝ ██╗
╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝
EOF
echo -e "\033[0m"

# Configuration
REPO_URL="https://github.com/VN-KEO/xmghostx.git"
INSTALL_DIR="/opt/mghostx"
CONFIG_DIR="/etc/mghostx"
LOG_DIR="/var/log/mghostx"
DATA_DIR="/var/lib/mghostx"
BIN_DIR="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; }
info() { echo -e "${BLUE}[*]${NC} $1"; }

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
        exit 1
    fi
}

# Install dependencies for Arch Linux
install_dependencies_arch() {
    info "Installing Arch Linux dependencies..."
    
    pacman -Syu --noconfirm
    pacman -S --noconfirm --needed \
        git \
        go \
        base-devel \
        openssl \
        curl \
        wget \
        tar \
        gzip \
        sqlite \
        nodejs \
        npm \
        python \
        python-pip \
        docker \
        docker-compose
    
    # Enable docker service
    systemctl enable --now docker
}

# Create directories
create_directories() {
    info "Creating directories..."
    
    # Create directories first
    mkdir -p $INSTALL_DIR
    mkdir -p $CONFIG_DIR
    mkdir -p $LOG_DIR
    mkdir -p $DATA_DIR
    mkdir -p $DATA_DIR/db
    mkdir -p $DATA_DIR/certs
    mkdir -p $DATA_DIR/plugins
    
    # Then set permissions
    chmod 750 $INSTALL_DIR
    chmod 750 $CONFIG_DIR
    chmod 750 $LOG_DIR
    chmod 750 $DATA_DIR
}

# Clone repository
clone_repository() {
    info "Cloning MGHOSTX repository..."
    
    if [ -d "$INSTALL_DIR/.git" ]; then
        warn "Repository already exists, updating..."
        cd $INSTALL_DIR
        git pull
    else
        git clone $REPO_URL $INSTALL_DIR
    fi
}

# Build from source
build_from_source() {
    info "Building MGHOSTX from source..."
    
    cd $INSTALL_DIR
    
    # Check Go version
    go version
    
    # Install Go dependencies
    go mod download
    
    # Build binaries
    info "Building server..."
    go build -o $INSTALL_DIR/bin/mghostx-server ./cmd/server
    
    info "Building agent..."
    go build -o $INSTALL_DIR/bin/mghostx-agent ./cmd/agent
    
    info "Building CLI..."
    go build -o $INSTALL_DIR/bin/mghostx-cli ./cmd/cli
    
    # Make binaries executable
    chmod +x $INSTALL_DIR/bin/*
}

# Generate configuration
generate_config() {
    info "Generating configuration..."
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Server config
    cat > $CONFIG_DIR/server.yaml << EOF
# MGHOSTX Server Configuration
version: 1.0.0

server:
  host: 0.0.0.0
  port: 8443
  grpc_port: 8444
  websocket_port: 8445
  metrics_port: 9090
  
  tls:
    enabled: true
    cert_path: $DATA_DIR/certs/server.crt
    key_path: $DATA_DIR/certs/server.key
    ca_path: $DATA_DIR/certs/ca.crt
  
  database:
    type: sqlite
    path: $DATA_DIR/db/mghostx.db
  
  auth:
    jwt_secret: $(openssl rand -hex 32)
    session_timeout: 24h
    
  ai:
    enabled: false
    provider: openai
    model: gpt-4
    api_key: ""
  
  logging:
    level: info
    file: $LOG_DIR/mghostx-server.log
    max_size: 100
    max_backups: 10
    max_age: 30
EOF

    # Agent config
    cat > $CONFIG_DIR/agent.yaml << EOF
# MGHOSTX Agent Configuration
version: 1.0.0

agent:
  id: $(hostname)-$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
  name: "$(hostname)"
  tags:
    - os:arch
    - type:server
  
  server:
    url: https://localhost:8443
    insecure_skip_verify: true
  
  heartbeat:
    interval: 30s
    timeout: 60s
  
  collection:
    enabled: true
    interval: 5m
    realtime: true
    
    collectors:
      - system_info
      - processes
      - network_connections
      - listening_ports
      - installed_packages
      - services
      - users
      - file_integrity:
          paths:
            - /etc
            - /bin
            - /usr/bin
            - /usr/local/bin
  
  logging:
    level: info
    file: $LOG_DIR/mghostx-agent.log
EOF
}

# Generate certificates
generate_certificates() {
    info "Generating TLS certificates..."
    
    local certs_dir="$DATA_DIR/certs"
    
    # Generate self-signed certificates
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$certs_dir/server.key" \
        -out "$certs_dir/server.crt" \
        -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=MGHOSTX/CN=localhost"
    
    # Copy as CA for simplicity (for testing)
    cp "$certs_dir/server.crt" "$certs_dir/ca.crt"
    
    chmod 600 "$certs_dir"/*
}

# Create systemd service
create_systemd_service() {
    info "Creating systemd service..."
    
    # Server service
    cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=mghostx
Group=mghostx
WorkingDirectory=$INSTALL_DIR
Environment="MGHOSTX_CONFIG=$CONFIG_DIR/server.yaml"
Environment="MGHOSTX_DATA=$DATA_DIR"

ExecStart=$INSTALL_DIR/bin/mghostx-server
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=mghostx-server

[Install]
WantedBy=multi-user.target
EOF

    # Agent service
    cat > /etc/systemd/system/mghostx-agent.service << EOF
[Unit]
Description=MGHOSTX Security Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="MGHOSTX_AGENT_CONFIG=$CONFIG_DIR/agent.yaml"

ExecStart=$INSTALL_DIR/bin/mghostx-agent
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=mghostx-agent

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# Create user
create_user() {
    info "Creating mghostx user..."
    
    if ! id "mghostx" &>/dev/null; then
        useradd -r -s /bin/false -d $DATA_DIR mghostx
    fi
    
    chown -R mghostx:mghostx $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR
}

# Setup firewall
setup_firewall() {
    info "Configuring firewall..."
    
    if command -v ufw &>/dev/null; then
        ufw allow 8443/tcp
        ufw reload
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --reload
    elif command -v iptables &>/dev/null; then
        iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
    else
        warn "No firewall manager found"
    fi
}

# Install CLI
install_cli() {
    info "Installing CLI..."
    
    ln -sf $INSTALL_DIR/bin/mghostx-cli $BIN_DIR/mghostx
}

# Post-install
post_install() {
    local admin_password=$(openssl rand -hex 8)
    echo "$admin_password" > $DATA_DIR/admin_password.txt
    chmod 600 $DATA_DIR/admin_password.txt
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MGHOSTX Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📁 Directories:"
    echo "   Installation: $INSTALL_DIR"
    echo "   Configuration: $CONFIG_DIR"
    echo "   Data: $DATA_DIR"
    echo "   Logs: $LOG_DIR"
    echo ""
    echo "🚀 Services:"
    echo "   Start server:  sudo systemctl start mghostx-server"
    echo "   Start agent:   sudo systemctl start mghostx-agent"
    echo "   Enable:        sudo systemctl enable mghostx-server"
    echo ""
    echo "🌐 Dashboard:"
    echo "   URL: https://localhost:8443"
    echo "   Username: admin"
    echo "   Password: $admin_password"
    echo ""
    echo "🔧 Commands:"
    echo "   Check status:  sudo systemctl status mghostx-server"
    echo "   View logs:     sudo journalctl -u mghostx-server -f"
    echo "   Use CLI:       mghostx --help"
    echo ""
}

# Main installation
main() {
    log "Starting MGHOSTX Installation for Arch Linux"
    
    check_root
    install_dependencies_arch
    create_directories
    clone_repository
    build_from_source
    generate_certificates
    generate_config
    create_user
    create_systemd_service
    setup_firewall
    install_cli
    post_install
    
    log "Installation completed!"
    echo ""
    echo "To start using MGHOSTX:"
    echo "1. sudo systemctl start mghostx-server"
    echo "2. sudo systemctl start mghostx-agent"
    echo "3. Open https://localhost:8443 in your browser"
}

main
