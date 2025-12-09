#!/bin/bash

# MGHOSTX Universal Installer
# Version: 1.0.0
# Author: MGHOSTX Security

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
MGHOSTX_VERSION="1.0.0"
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

# Logging
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[!]${NC} $1"
}

info() {
    echo -e "${BLUE}[*]${NC} $1"
}

# Check OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        VER=$(cat /etc/redhat-release | sed -E 's/.*release ([0-9]+).*/\1/')
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        VER=$(uname -r)
    fi
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    log "Detected OS: $OS $VER ($ARCH)"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    local missing=()
    
    # Check for required commands
    for cmd in curl wget tar git systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    # OS-specific dependencies
    case $OS in
        ubuntu|debian)
            if ! dpkg -l | grep -q libssl-dev; then
                missing+=("libssl-dev")
            fi
            ;;
        centos|rhel|fedora)
            if ! rpm -q openssl-devel &> /dev/null; then
                missing+=("openssl-devel")
            fi
            ;;
    esac
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing[*]}"
        install_dependencies "${missing[@]}"
    fi
}

install_dependencies() {
    info "Installing dependencies..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y "$@" curl wget tar git systemctl libssl-dev ca-certificates build-essential
            ;;
        centos|rhel)
            yum install -y "$@" curl wget tar git systemd openssl-devel ca-certificates gcc make
            ;;
        fedora)
            dnf install -y "$@" curl wget tar git systemd openssl-devel ca-certificates gcc make
            ;;
        arch)
            pacman -Syu --noconfirm "$@" curl wget tar git systemd openssl ca-certificates base-devel
            ;;
        *)
            warn "Unsupported OS for automatic dependency installation"
            ;;
    esac
}

# Clone or download MGHOSTX
download_mghostx() {
    info "Downloading MGHOSTX from repository..."
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    
    # Clone repository
    log "Cloning repository from: $REPO_URL"
    if ! git clone "$REPO_URL" "$temp_dir/mghostx"; then
        error "Failed to clone repository!"
        exit 1
    fi
    
    # Check if it's a source repository or binary release
    if [ -f "$temp_dir/mghostx/Makefile" ]; then
        log "Source repository detected, building from source..."
        build_from_source "$temp_dir/mghostx"
    elif [ -f "$temp_dir/mghostx/bin/mghostx-server" ]; then
        log "Binary release detected, installing binaries..."
        cp -r "$temp_dir/mghostx/bin" "$INSTALL_DIR/"
    else
        error "Repository doesn't contain expected files"
        exit 1
    fi
    
    # Copy additional files
    if [ -d "$temp_dir/mghostx/config" ]; then
        cp -r "$temp_dir/mghostx/config" "$INSTALL_DIR/"
    fi
    
    if [ -d "$temp_dir/mghostx/scripts" ]; then
        cp -r "$temp_dir/mghostx/scripts" "$INSTALL_DIR/"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log "MGHOSTX downloaded to $INSTALL_DIR"
}

# Build from source
build_from_source() {
    local source_dir=$1
    
    info "Building MGHOSTX from source..."
    
    cd "$source_dir"
    
    # Check for Go
    if ! command -v go &> /dev/null; then
        warn "Go not found, installing..."
        install_go
    fi
    
    # Build
    if [ -f "Makefile" ]; then
        make build
    elif [ -f "go.mod" ]; then
        go build -o bin/mghostx-server ./cmd/server
        go build -o bin/mghostx-agent ./cmd/agent
        go build -o bin/mghostx-cli ./cmd/cli
    else
        error "Cannot determine build system"
        exit 1
    fi
    
    # Copy binaries
    mkdir -p "$INSTALL_DIR/bin"
    cp -r bin/* "$INSTALL_DIR/bin/"
    
    log "Build completed successfully"
}

# Install Go if needed
install_go() {
    local go_version="1.21.0"
    
    case $OS in
        ubuntu|debian)
            wget https://golang.org/dl/go${go_version}.linux-${ARCH}.tar.gz
            tar -C /usr/local -xzf go${go_version}.linux-${ARCH}.tar.gz
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
            source /etc/profile
            ;;
        centos|rhel|fedora)
            wget https://golang.org/dl/go${go_version}.linux-${ARCH}.tar.gz
            tar -C /usr/local -xzf go${go_version}.linux-${ARCH}.tar.gz
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
            source /etc/profile
            ;;
        *)
            error "Automatic Go installation not supported for $OS"
            exit 1
            ;;
    esac
}

# Create directories
create_directories() {
    info "Creating directories..."
    
    mkdir -p $CONFIG_DIR
    mkdir -p $LOG_DIR
    mkdir -p $DATA_DIR
    mkdir -p $DATA_DIR/db
    mkdir -p $DATA_DIR/certs
    mkdir -p $DATA_DIR/plugins
    
    # Set permissions
    chmod 750 $INSTALL_DIR
    chmod 750 $CONFIG_DIR
    chmod 750 $LOG_DIR
    chmod 750 $DATA_DIR
}

# Generate configuration
generate_config() {
    info "Generating configuration..."
    
    # Detect IP address
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Generate server config
    cat > $CONFIG_DIR/server.yaml << EOF
# MGHOSTX Server Configuration
version: 1.0.0

server:
  host: $server_ip
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
    enabled: true
    provider: openai
    model: gpt-4
    api_key: ""
    cache_ttl: 3600
  
  logging:
    level: info
    file: $LOG_DIR/mghostx-server.log
    max_size: 100
    max_backups: 10
    max_age: 30

  agents:
    auto_approve: false
    heartbeat_interval: 30s
    reconnect_timeout: 5m
    
  collection:
    batch_size: 1000
    flush_interval: 10s
    retention_days: 90
EOF

    # Generate agent config template
    cat > $CONFIG_DIR/agent-template.yaml << EOF
# MGHOSTX Agent Configuration
version: 1.0.0

agent:
  id: \${HOSTNAME}-\${UUID}
  name: "\${HOSTNAME}"
  tags:
    - os:\${OS}
    - role:\${ROLE}
  
  server:
    url: https://$server_ip:8443
    grpc_url: $server_ip:8444
    insecure_skip_verify: false
  
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
      - installed_software
  
  security:
    encryption_key: $(openssl rand -hex 32)
    max_memory: 256
    cpu_limit: 25
    
  logging:
    level: info
    file: /var/log/mghostx/agent.log
    max_size: 50
    max_backups: 5
EOF

    log "Configuration generated in $CONFIG_DIR"
}

# Generate certificates
generate_certificates() {
    info "Generating TLS certificates..."
    
    local certs_dir="$DATA_DIR/certs"
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Generate CA
    openssl genrsa -out "$certs_dir/ca.key" 4096 2>/dev/null
    openssl req -x509 -new -nodes -key "$certs_dir/ca.key" \
        -sha256 -days 3650 -out "$certs_dir/ca.crt" \
        -subj "/C=US/ST=CA/L=San Francisco/O=MGHOSTX/CN=MGHOSTX CA" 2>/dev/null
    
    # Generate server certificate
    openssl genrsa -out "$certs_dir/server.key" 2048 2>/dev/null
    openssl req -new -key "$certs_dir/server.key" \
        -out "$certs_dir/server.csr" \
        -subj "/C=US/ST=CA/L=San Francisco/O=MGHOSTX/CN=$server_ip" 2>/dev/null
    
    cat > "$certs_dir/server.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $server_ip
IP.1 = $server_ip
EOF
    
    openssl x509 -req -in "$certs_dir/server.csr" \
        -CA "$certs_dir/ca.crt" -CAkey "$certs_dir/ca.key" -CAcreateserial \
        -out "$certs_dir/server.crt" -days 825 -sha256 \
        -extfile "$certs_dir/server.ext" 2>/dev/null
    
    # Cleanup
    rm "$certs_dir/server.csr" "$certs_dir/server.ext" "$certs_dir/ca.srl"
    
    log "Certificates generated in $certs_dir"
}

# Create systemd service
create_systemd_service() {
    info "Creating systemd service..."
    
    cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Monitoring Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=mghostx
Group=mghostx
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/bin:/usr/local/bin:/usr/bin:/bin"
Environment="MGHOSTX_CONFIG=$CONFIG_DIR/server.yaml"
Environment="MGHOSTX_DATA=$DATA_DIR"

ExecStart=$INSTALL_DIR/bin/mghostx-server
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $LOG_DIR
CapabilityBoundingSet=
SystemCallFilter=@system-service

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mghostx-server

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/mghostx-agent.service << EOF
[Unit]
Description=MGHOSTX Security Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/bin:/usr/local/bin:/usr/bin:/bin"
Environment="MGHOSTX_AGENT_CONFIG=$CONFIG_DIR/agent.yaml"

ExecStart=$INSTALL_DIR/bin/mghostx-agent
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR
ReadOnlyPaths=/proc /sys

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mghostx-agent

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "Systemd services created"
}

# Create mghostx user
create_user() {
    info "Creating mghostx user..."
    
    if id "mghostx" &>/dev/null; then
        log "User mghostx already exists"
    else
        useradd -r -s /bin/false -d $DATA_DIR mghostx
        log "User mghostx created"
    fi
    
    # Set ownership
    chown -R mghostx:mghostx $INSTALL_DIR
    chown -R mghostx:mghostx $CONFIG_DIR
    chown -R mghostx:mghostx $LOG_DIR
    chown -R mghostx:mghostx $DATA_DIR
}

# Setup firewall
setup_firewall() {
    info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 8443/tcp comment "MGHOSTX HTTPS"
        ufw allow 8444/tcp comment "MGHOSTX gRPC"
        ufw allow 8445/tcp comment "MGHOSTX WebSocket"
        ufw allow 9090/tcp comment "MGHOSTX Metrics"
        ufw reload
        log "UFW configured"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --permanent --add-port=8444/tcp
        firewall-cmd --permanent --add-port=8445/tcp
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --reload
        log "Firewalld configured"
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
        iptables -A INPUT -p tcp --dport 8444 -j ACCEPT
        iptables -A INPUT -p tcp --dport 8445 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
        log "iptables configured"
    else
        warn "No firewall manager found, ports may need manual configuration"
    fi
}

# Install CLI
install_cli() {
    info "Installing CLI..."
    
    # Create symlink
    if [ -f "$INSTALL_DIR/bin/mghostx-cli" ]; then
        ln -sf "$INSTALL_DIR/bin/mghostx-cli" "$BIN_DIR/mghostx"
    elif [ -f "$INSTALL_DIR/bin/mghostx" ]; then
        ln -sf "$INSTALL_DIR/bin/mghostx" "$BIN_DIR/mghostx"
    fi
    
    log "CLI installed to $BIN_DIR/mghostx"
}

# Post-install instructions
post_install() {
    local server_ip=$(hostname -I | awk '{print $1}')
    local admin_password=$(openssl rand -hex 8)
    
    # Create admin password file
    echo "$admin_password" > "$DATA_DIR/admin_password.txt"
    chmod 600 "$DATA_DIR/admin_password.txt"
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MGHOSTX Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📁 Directories:"
    echo "   Configuration: $CONFIG_DIR"
    echo "   Logs: $LOG_DIR"
    echo "   Data: $DATA_DIR"
    echo "   Installation: $INSTALL_DIR"
    echo ""
    echo "🚀 Services:"
    echo "   Start server: systemctl start mghostx-server"
    echo "   Enable auto-start: systemctl enable mghostx-server"
    echo "   Check status: systemctl status mghostx-server"
    echo ""
    echo "🔧 Configuration:"
    echo "   Server config: $CONFIG_DIR/server.yaml"
    echo "   Agent template: $CONFIG_DIR/agent-template.yaml"
    echo ""
    echo "🔑 Dashboard Access:"
    echo "   URL: https://$server_ip:8443"
    echo "   Username: admin"
    echo "   Password: $admin_password"
    echo ""
    echo "📚 Source Repository:"
    echo "   $REPO_URL"
    echo ""
    echo "🔗 Next Steps:"
    echo "   1. Log in to the dashboard"
    echo "   2. Set your OpenAI API key in server.yaml"
    echo "   3. Generate agent configs"
    echo "   4. Deploy agents to endpoints"
    echo ""
}

# Main installation
main() {
    log "Starting MGHOSTX Installation v$MGHOSTX_VERSION"
    
    # Check root
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
        exit 1
    fi
    
    # Detect OS
    detect_os
    
    # Check dependencies
    check_dependencies
    
    # Create directories
    create_directories
    
    # Download from repository
    download_mghostx
    
    # Generate certificates
    generate_certificates
    
    # Generate config
    generate_config
    
    # Create user
    create_user
    
    # Create systemd service
    create_systemd_service
    
    # Setup firewall
    setup_firewall
    
    # Install CLI
    install_cli
    
    # Post-install
    post_install
    
    log "Installation completed successfully!"
}

# Run main
main "$@"
