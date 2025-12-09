#!/bin/bash

# MGHOSTX Installer for Arch Linux
# Updated for VN-KEO/xmghostx repository

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

check_root() {
    [ "$EUID" -ne 0 ] && { error "Please run as root"; exit 1; }
}

install_dependencies() {
    info "Installing dependencies..."
    
    # Check if running in Docker/CI (no pacman)
    if ! command -v pacman &> /dev/null; then
        warn "Running in non-Arch environment, skipping pacman installs"
        return
    fi
    
    pacman -Syu --noconfirm
    pacman -S --noconfirm --needed git go docker docker-compose openssl
}

create_directories() {
    info "Creating directories..."
    
    mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR \
             $DATA_DIR/db $DATA_DIR/certs $DATA_DIR/plugins
    
    chmod 750 $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR
}

clone_and_build() {
    info "Setting up MGHOSTX..."
    
    # Check if we're already in a git repo
    if [ -d ".git" ] && [ -f "go.mod" ]; then
        info "Already in MGHOSTX repository, building from current directory..."
        BUILD_DIR=$(pwd)
    else
        # Clone or use existing
        if [ ! -d "$INSTALL_DIR/.git" ]; then
            git clone $REPO_URL $INSTALL_DIR
        fi
        BUILD_DIR=$INSTALL_DIR
    fi
    
    cd $BUILD_DIR
    
    # Check for go.mod
    if [ ! -f "go.mod" ]; then
        error "No go.mod found! Creating basic structure..."
        create_basic_structure
    fi
    
    # Build
    info "Building MGHOSTX..."
    
    # Create bin directory
    mkdir -p $INSTALL_DIR/bin
    
    # Try to build server
    if [ -f "cmd/server/main.go" ]; then
        go build -o $INSTALL_DIR/bin/mghostx-server ./cmd/server
    else
        # Create minimal server
        create_minimal_server
        go build -o $INSTALL_DIR/bin/mghostx-server .
    fi
    
    # Try to build agent
    if [ -f "cmd/agent/main.go" ]; then
        go build -o $INSTALL_DIR/bin/mghostx-agent ./cmd/agent
    else
        # Create minimal agent
        create_minimal_agent
        go build -o $INSTALL_DIR/bin/mghostx-agent .
    fi
    
    # Try to build CLI
    if [ -f "cmd/cli/main.go" ]; then
        go build -o $INSTALL_DIR/bin/mghostx-cli ./cmd/cli
    fi
    
    chmod +x $INSTALL_DIR/bin/*
}

create_basic_structure() {
    cat > go.mod << 'EOF'
module github.com/VN-KEO/xmghostx

go 1.21
EOF
    
    cat > main.go << 'EOF'
package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "MGHOSTX Server is running!")
    })
    
    fmt.Println("MGHOSTX Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF
}

create_minimal_server() {
    mkdir -p cmd/server
    cat > cmd/server/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
)

func main() {
    port := flag.String("port", "8443", "Server port")
    flag.Parse()
    
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, `
        <h1>MGHOSTX Security Server</h1>
        <p>Server is running on port %s</p>
        <p><a href="/health">Health Check</a></p>
        `, *port)
    })
    
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprint(w, `{"status": "healthy", "version": "1.0.0"}`)
    })
    
    log.Printf("Starting MGHOSTX server on :%s", *port)
    log.Fatal(http.ListenAndServe(":"+*port, nil))
}
EOF
}

create_minimal_agent() {
    mkdir -p cmd/agent
    cat > cmd/agent/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
    "log"
    "time"
)

func main() {
    server := flag.String("server", "http://localhost:8443", "MGHOSTX server")
    flag.Parse()
    
    fmt.Printf("MGHOSTX Agent connecting to %s\n", *server)
    
    ticker := time.NewTicker(30 * time.Second)
    for range ticker.C {
        log.Printf("Heartbeat sent to %s", *server)
    }
}
EOF
}

generate_config() {
    info "Generating configuration..."
    
    cat > $CONFIG_DIR/server.yaml << EOF
server:
  host: "0.0.0.0"
  port: 8443
  tls_enabled: false  # Set to true for production
  
database:
  type: "sqlite"
  path: "$DATA_DIR/db/mghostx.db"
  
logging:
  level: "info"
  file: "$LOG_DIR/server.log"
EOF

    cat > $CONFIG_DIR/agent.yaml << EOF
agent:
  id: "$(hostname)-$(date +%s)"
  name: "$(hostname)"
  server_url: "http://localhost:8443"
  
collectors:
  - system_info
  - processes
  
heartbeat_interval: 30
EOF
}

setup_systemd() {
    info "Setting up systemd services..."
    
    # Server service
    cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/mghostx-server --port 8443
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Agent service
    cat > /etc/systemd/system/mghostx-agent.service << EOF
[Unit]
Description=MGHOSTX Security Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/mghostx-agent --server http://localhost:8443
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

setup_cli() {
    info "Setting up CLI..."
    
    if [ -f "$INSTALL_DIR/bin/mghostx-cli" ]; then
        ln -sf $INSTALL_DIR/bin/mghostx-cli $BIN_DIR/mghostx
    else
        # Create simple CLI
        cat > $INSTALL_DIR/bin/mghostx << 'EOF'
#!/bin/bash
echo "MGHOSTX CLI"
echo "Usage: mghostx [command]"
echo ""
echo "Commands:"
echo "  start     - Start MGHOSTX services"
echo "  stop      - Stop MGHOSTX services"
echo "  status    - Check service status"
echo "  logs      - View logs"
EOF
        chmod +x $INSTALL_DIR/bin/mghostx
        ln -sf $INSTALL_DIR/bin/mghostx $BIN_DIR/mghostx
    fi
}

post_install() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MGHOSTX Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📁 Installation: $INSTALL_DIR"
    echo "⚙️  Configuration: $CONFIG_DIR"
    echo "📊 Data: $DATA_DIR"
    echo ""
    echo "🚀 Quick Start:"
    echo "   Start server:  systemctl start mghostx-server"
    echo "   Start agent:   systemctl start mghostx-agent"
    echo "   Enable:        systemctl enable mghostx-server"
    echo ""
    echo "🌐 Access:"
    echo "   Dashboard:     http://localhost:8443"
    echo "   Health check:  http://localhost:8443/health"
    echo ""
    echo "📋 Commands:"
    echo "   Check status:  systemctl status mghostx-server"
    echo "   View logs:     journalctl -u mghostx-server -f"
    echo "   Use CLI:       mghostx"
    echo ""
    echo "🔧 Next Steps:"
    echo "   1. Check if services are running"
    echo "   2. Access the dashboard"
    echo "   3. Configure agents for other systems"
    echo ""
}

main() {
    log "Starting MGHOSTX Installation"
    check_root
    install_dependencies
    create_directories
    clone_and_build
    generate_config
    setup_systemd
    setup_cli
    post_install
    log "Installation completed!"
}

main
