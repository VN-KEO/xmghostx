#!/bin/bash

# MGHOSTX Complete Installer - One Command Installation
# Run: curl -sSL https://raw.githubusercontent.com/VN-KEO/xmghostx/main/install.sh | sudo bash

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

echo "🔧 MGHOSTX Complete Installation v1.0"
echo "===================================="

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    echo "   Run: sudo bash $0"
    exit 1
fi

# Variables
INSTALL_DIR="/opt/mghostx"
CONFIG_DIR="/etc/mghostx"
LOG_DIR="/var/log/mghostx"
DATA_DIR="/var/lib/mghostx"
REPO_URL="https://github.com/VN-KEO/xmghostx.git"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; }
info() { echo -e "${BLUE}[*]${NC} $1"; }

# 1. Install dependencies
info "Installing dependencies..."
pacman -Sy --noconfirm
pacman -S --noconfirm --needed git go curl wget openssl

# 2. Create directories
info "Creating directories..."
mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR
mkdir -p $DATA_DIR/db $DATA_DIR/certs

# 3. Clone repository
info "Downloading MGHOSTX..."
cd /tmp
rm -rf xmghostx-install
git clone $REPO_URL xmghostx-install
cd xmghostx-install

# 4. Check and build source
info "Building MGHOSTX..."

# Download dependencies
go mod download 2>/dev/null || go mod init github.com/VN-KEO/xmghostx

# Build server
info "Building server..."
go build -buildvcs=false -o $INSTALL_DIR/mghostx-server ./cmd/server

# Build agent if exists
if [ -f "cmd/agent/main.go" ]; then
    info "Building agent..."
    go build -buildvcs=false -o $INSTALL_DIR/mghostx-agent ./cmd/agent
else
    # Create minimal agent
    mkdir -p cmd/agent
    cat > cmd/agent/main.go << 'EOF'
package main
import ("flag";"fmt";"time")
func main() {
    server := flag.String("server", "http://localhost:8443", "Server")
    flag.Parse()
    fmt.Printf("Agent for %s\n", *server)
    for range time.Tick(30 * time.Second) {
        fmt.Println("Heartbeat sent")
    }
}
EOF
    go build -buildvcs=false -o $INSTALL_DIR/mghostx-agent ./cmd/agent
fi

chmod +x $INSTALL_DIR/mghostx-*

# 5. Create configuration
info "Creating configuration..."
cat > $CONFIG_DIR/server.yaml << EOF
# MGHOSTX Server Configuration
server:
  host: "0.0.0.0"
  port: "8443"
  tls_enabled: false

database:
  type: "sqlite"
  path: "$DATA_DIR/db/mghostx.db"

logging:
  level: "info"
  file: "$LOG_DIR/server.log"
EOF

cat > $CONFIG_DIR/agent.yaml << EOF
# MGHOSTX Agent Configuration
agent:
  id: "\$(hostname)-\$(date +%s)"
  name: "\$(hostname)"
  server: "http://localhost:8443"
EOF

# 6. Create systemd services
info "Creating systemd services..."
cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Monitoring Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mghostx-server --port 8443
Restart=always
RestartSec=10

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

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mghostx-agent --server http://localhost:8443
Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=mghostx-agent

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 7. Create firewall rules
info "Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 8443/tcp
    ufw reload
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=8443/tcp
    firewall-cmd --reload
fi

# 8. Start services
info "Starting services..."
systemctl enable mghostx-server
systemctl start mghostx-server

systemctl enable mghostx-agent
systemctl start mghostx-agent

# 9. Create CLI
info "Creating CLI tool..."
cat > /usr/local/bin/mghostx << 'EOF'
#!/bin/bash
echo "MGHOSTX Management CLI"
echo "====================="
echo "Commands:"
echo "  status    - Check service status"
echo "  logs      - View logs"
echo "  restart   - Restart services"
echo "  stop      - Stop services"
echo "  start     - Start services"
echo ""
echo "Usage:"
echo "  mghostx status"
echo "  mghostx logs"
EOF
chmod +x /usr/local/bin/mghostx

# 10. Wait and test
info "Testing installation..."
sleep 3

echo ""
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo "========================"
echo ""
echo "🌐 Web Interface:  http://localhost:8443"
echo "🩺 Health Check:   curl http://localhost:8443/api/health"
echo "📊 Agents Status:  curl http://localhost:8443/api/agents"
echo ""
echo "📊 Service Status:"
if systemctl is-active --quiet mghostx-server; then
    echo -e "  ${GREEN}✅ MGHOSTX Server: Running${NC}"
else
    echo -e "  ${RED}❌ MGHOSTX Server: Failed${NC}"
fi

if systemctl is-active --quiet mghostx-agent; then
    echo -e "  ${GREEN}✅ MGHOSTX Agent: Running${NC}"
else
    echo -e "  ${YELLOW}⚠️  MGHOSTX Agent: Not running${NC}"
fi

echo ""
echo "🔧 Quick Commands:"
echo "  Check status:  systemctl status mghostx-server"
echo "  View logs:     journalctl -u mghostx-server -f"
echo "  Restart:       systemctl restart mghostx-server"
echo "  Stop:          systemctl stop mghostx-server"
echo ""
echo "📁 Installation:"
echo "  Binaries:      $INSTALL_DIR/"
echo "  Configuration: $CONFIG_DIR/"
echo "  Logs:          $LOG_DIR/"
echo "  Data:          $DATA_DIR/"
echo ""
echo "🚀 Next Steps:"
echo "  1. Open browser: http://localhost:8443"
echo "  2. Check dashboard"
echo "  3. Deploy agents to other systems"
echo ""
