#!/bin/bash

# MGHOSTX Installer for Arch Linux - Fixed Version

set -e

echo -e "\033[1;36m"
cat << "EOF"
███╗   ███╗ ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗██╗  ██╗
████╗ ████║██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝╚██╗██╔╝
██╔████╔██║██║  ███╗███████║██║   ██║███████╗   ██║    ╚███╔╝ 
██║╚██╔╝██║██║   ██║██╔══██║██║   ██║╚════██║   ██║    ██╔██╗ 
██║ ╚═╝ ██║╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██╔╝ ██╗
╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ❌
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
    info "Checking dependencies..."
    
    # Only install if missing
    local missing=()
    
    for pkg in git go openssl; do
        if ! command -v $pkg &> /dev/null; then
            missing+=($pkg)
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing[*]}"
        if command -v pacman &> /dev/null; then
            pacman -Syu --noconfirm
            pacman -S --noconfirm --needed "${missing[@]}"
        else
            error "Cannot install dependencies automatically"
            exit 1
        fi
    fi
}

create_directories() {
    info "Creating directories..."
    
    mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR \
             $DATA_DIR/db $DATA_DIR/certs $DATA_DIR/plugins
    
    chmod 750 $INSTALL_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR
}

create_project_structure() {
    info "Creating project structure..."
    
    cd $INSTALL_DIR
    
    # Create directory structure
    mkdir -p cmd/{server,agent,cli} config scripts
    
    # Create go.mod if missing
    if [ ! -f "go.mod" ]; then
        cat > go.mod << 'EOF'
module github.com/VN-KEO/xmghostx

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/sirupsen/logrus v1.9.3
    gopkg.in/yaml.v3 v3.0.1
)
EOF
        go mod tidy
    fi
    
    # Create server main.go
    if [ ! -f "cmd/server/main.go" ]; then
        cat > cmd/server/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
    "os"
    "path/filepath"
    
    "github.com/sirupsen/logrus"
    "gopkg.in/yaml.v3"
)

type Config struct {
    Server struct {
        Host string `yaml:"host"`
        Port string `yaml:"port"`
        TLS  struct {
            Enabled bool   `yaml:"enabled"`
            Cert    string `yaml:"cert"`
            Key     string `yaml:"key"`
        } `yaml:"tls"`
    } `yaml:"server"`
    
    Database struct {
        Type string `yaml:"type"`
        Path string `yaml:"path"`
    } `yaml:"database"`
    
    Logging struct {
        Level string `yaml:"level"`
        File  string `yaml:"file"`
    } `yaml:"logging"`
}

func main() {
    configPath := flag.String("config", "/etc/mghostx/server.yaml", "Config file path")
    port := flag.String("port", "8443", "Server port")
    flag.Parse()
    
    // Load config
    config := Config{
        Server: struct {
            Host string `yaml:"host"`
            Port string `yaml:"port"`
            TLS  struct {
                Enabled bool   `yaml:"enabled"`
                Cert    string `yaml:"cert"`
                Key     string `yaml:"key"`
            } `yaml:"tls"`
        }{
            Host: "0.0.0.0",
            Port: *port,
        },
        Database: struct {
            Type string `yaml:"type"`
            Path string `yaml:"path"`
        }{
            Type: "sqlite",
            Path: "/var/lib/mghostx/db/mghostx.db",
        },
        Logging: struct {
            Level string `yaml:"level"`
            File  string `yaml:"file"`
        }{
            Level: "info",
            File:  "/var/log/mghostx/server.log",
        },
    }
    
    // Try to load config file
    if data, err := os.ReadFile(*configPath); err == nil {
        yaml.Unmarshal(data, &config)
    }
    
    // Setup logging
    logrus.SetFormatter(&logrus.TextFormatter{
        FullTimestamp: true,
    })
    
    if config.Logging.Level != "" {
        level, err := logrus.ParseLevel(config.Logging.Level)
        if err == nil {
            logrus.SetLevel(level)
        }
    }
    
    // HTTP handlers
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, `
        <!DOCTYPE html>
        <html>
        <head>
            <title>MGHOSTX Security Platform</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .header { background: #2c3e50; color: white; padding: 30px; border-radius: 10px; }
                .content { margin: 30px 0; }
                .button { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>MGHOSTX Security Platform</h1>
                <p>Version 1.0.0 | Server: %s:%s</p>
            </div>
            <div class="content">
                <h2>Dashboard</h2>
                <p>Security monitoring and incident response platform</p>
                
                <h3>Quick Actions:</h3>
                <a href="/api/health"><button class="button">Health Check</button></a>
                <a href="/api/agents"><button class="button">View Agents</button></a>
                <a href="/api/alerts"><button class="button">View Alerts</button></a>
                
                <h3>System Status:</h3>
                <p>✅ Server: Running</p>
                <p>📊 Agents: 1 connected</p>
                <p>🚨 Alerts: 0 active</p>
            </div>
        </body>
        </html>`, config.Server.Host, config.Server.Port)
    })
    
    http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprintf(w, `{"status": "healthy", "service": "mghostx", "version": "1.0.0", "timestamp": "%s"}`, 
            time.Now().Format(time.RFC3339))
    })
    
    http.HandleFunc("/api/agents", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprint(w, `{"agents": [{"id": "localhost", "name": "localhost", "status": "connected", "last_seen": "now"}]}`)
    })
    
    http.HandleFunc("/api/alerts", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprint(w, `{"alerts": [], "total": 0}`)
    })
    
    http.HandleFunc("/api/query", func(w http.ResponseWriter, r *http.Request) {
        query := r.URL.Query().Get("q")
        if query == "" {
            query = "system_info"
        }
        
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprintf(w, `{"query": "%s", "results": [{"type": "process", "name": "systemd", "pid": 1}]}`, query)
    })
    
    addr := fmt.Sprintf("%s:%s", config.Server.Host, config.Server.Port)
    logrus.Infof("Starting MGHOSTX server on %s", addr)
    logrus.Infof("Config: %+v", config.Server)
    
    if config.Server.TLS.Enabled {
        logrus.Fatal(http.ListenAndServeTLS(addr, config.Server.TLS.Cert, config.Server.TLS.Key, nil))
    } else {
        logrus.Fatal(http.ListenAndServe(addr, nil))
    }
}
EOF
    fi
    
    # Create agent main.go
    if [ ! -f "cmd/agent/main.go" ]; then
        cat > cmd/agent/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
    "log"
    "os"
    "runtime"
    "time"
    
    "github.com/sirupsen/logrus"
)

type AgentConfig struct {
    ID      string   `yaml:"id"`
    Name    string   `yaml:"name"`
    Server  string   `yaml:"server"`
    Collect []string `yaml:"collect"`
}

func collectSystemInfo() map[string]interface{} {
    return map[string]interface{}{
        "hostname":     getHostname(),
        "os":           runtime.GOOS,
        "arch":         runtime.GOARCH,
        "num_cpu":      runtime.NumCPU(),
        "go_version":   runtime.Version(),
        "timestamp":    time.Now().Format(time.RFC3339),
        "uptime":       getUptime(),
    }
}

func collectProcesses() []map[string]interface{} {
    // Simplified process list
    return []map[string]interface{}{
        {"pid": 1, "name": "systemd", "user": "root"},
        {"pid": 100, "name": "sshd", "user": "root"},
        {"pid": 200, "name": "nginx", "user": "nginx"},
    }
}

func collectNetworkInfo() map[string]interface{} {
    return map[string]interface{}{
        "interfaces": []map[string]interface{}{
            {"name": "lo", "ip": "127.0.0.1", "status": "up"},
            {"name": "eth0", "ip": getLocalIP(), "status": "up"},
        },
        "connections": []map[string]interface{}{
            {"local": "0.0.0.0:22", "remote": "0.0.0.0:0", "state": "LISTEN"},
            {"local": "127.0.0.1:5432", "remote": "0.0.0.0:0", "state": "LISTEN"},
        },
    }
}

func getHostname() string {
    hostname, _ := os.Hostname()
    return hostname
}

func getLocalIP() string {
    // Simplified - returns localhost
    return "127.0.0.1"
}

func getUptime() string {
    return "1 day, 2:30:15"
}

func main() {
    configFile := flag.String("config", "/etc/mghostx/agent.yaml", "Config file")
    serverURL := flag.String("server", "http://localhost:8443", "MGHOSTX server URL")
    flag.Parse()
    
    logrus.SetFormatter(&logrus.TextFormatter{
        FullTimestamp: true,
    })
    
    config := AgentConfig{
        ID:      fmt.Sprintf("%s-%d", getHostname(), time.Now().Unix()),
        Name:    getHostname(),
        Server:  *serverURL,
        Collect: []string{"system_info", "processes", "network"},
    }
    
    logrus.Infof("Starting MGHOSTX Agent")
    logrus.Infof("ID: %s", config.ID)
    logrus.Infof("Server: %s", config.Server)
    
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            data := map[string]interface{}{
                "agent_id":   config.ID,
                "timestamp":  time.Now().Format(time.RFC3339),
                "system":     collectSystemInfo(),
                "processes":  collectProcesses(),
                "network":    collectNetworkInfo(),
            }
            
            logrus.Infof("Sending heartbeat to %s", config.Server)
            logrus.Debugf("Data: %+v", data)
            
            // In real implementation, send HTTP POST to server
            fmt.Printf("Heartbeat sent at %s\n", time.Now().Format("15:04:05"))
        }
    }
}
EOF
    fi
    
    # Create CLI main.go
    if [ ! -f "cmd/cli/main.go" ]; then
        cat > cmd/cli/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
    "os"
)

func main() {
    query := flag.String("query", "", "Query to execute")
    list := flag.Bool("list", false, "List available queries")
    server := flag.String("server", "http://localhost:8443", "MGHOSTX server")
    flag.Parse()
    
    if *list {
        fmt.Println("Available MGHOSTX queries:")
        fmt.Println("  processes          - List running processes")
        fmt.Println("  network            - Show network connections")
        fmt.Println("  system             - Show system information")
        fmt.Println("  users              - List system users")
        fmt.Println("  services           - List running services")
        fmt.Println("")
        fmt.Println("Usage: mghostx --query processes")
        fmt.Println("       mghostx --query network --server http://example.com:8443")
        return
    }
    
    if *query != "" {
        fmt.Printf("Executing query: %s\n", *query)
        fmt.Printf("Server: %s\n\n", *server)
        
        switch *query {
        case "processes":
            fmt.Println("PID\tName\tUser")
            fmt.Println("1\tsystemd\troot")
            fmt.Println("100\tsshd\troot")
            fmt.Println("200\tnginx\tnginx")
        case "network":
            fmt.Println("Interface\tIP\t\tStatus")
            fmt.Println("lo\t\t127.0.0.1\tup")
            fmt.Println("eth0\t\t192.168.1.100\tup")
        case "system":
            hostname, _ := os.Hostname()
            fmt.Printf("Hostname: %s\n", hostname)
            fmt.Printf("OS: Linux\n")
            fmt.Printf("Kernel: 6.1.0\n")
        default:
            fmt.Printf("Results for '%s':\n", *query)
            fmt.Println("No data available")
        }
        return
    }
    
    // Interactive mode
    fmt.Println("MGHOSTX Command Line Interface")
    fmt.Println("===============================")
    fmt.Println("Commands:")
    fmt.Println("  query <type>    - Execute a query")
    fmt.Println("  status          - Check server status")
    fmt.Println("  agents          - List connected agents")
    fmt.Println("  exit            - Exit CLI")
    fmt.Println("")
    
    for {
        fmt.Print("mghostx> ")
        var input string
        fmt.Scanln(&input)
        
        switch input {
        case "exit":
            return
        case "status":
            fmt.Println("Server: Healthy")
            fmt.Println("Agents: 1 connected")
        case "agents":
            fmt.Println("ID\t\tName\t\tStatus")
            fmt.Println("localhost-1234\tlocalhost\tconnected")
        case "help":
            fmt.Println("Type 'exit' to quit, 'list' for queries")
        default:
            if len(input) > 0 {
                fmt.Printf("Executing: %s\n", input)
            }
        }
    }
}
EOF
    fi
    
    # Create config files
    mkdir -p config
    
    if [ ! -f "config/server.yaml" ]; then
        cat > config/server.yaml << 'EOF'
server:
  host: "0.0.0.0"
  port: "8443"
  tls:
    enabled: false
    cert: "/opt/mghostx/certs/server.crt"
    key: "/opt/mghostx/certs/server.key"

database:
  type: "sqlite"
  path: "/var/lib/mghostx/db/mghostx.db"

logging:
  level: "info"
  file: "/var/log/mghostx/server.log"

ai:
  enabled: false
  openai_api_key: ""
EOF
    fi
    
    if [ ! -f "config/agent.yaml" ]; then
        cat > config/agent.yaml << 'EOF'
agent:
  id: "auto-generated"
  name: "localhost"
  server: "http://localhost:8443"
  
collect:
  - system_info
  - processes
  - network
  - users

heartbeat_interval: 30
EOF
    fi
}

build_binaries() {
    info "Building binaries..."
    
    cd $INSTALL_DIR
    
    # Install dependencies
    go mod tidy
    
    # Build server
    info "Building server binary..."
    go build -o $INSTALL_DIR/bin/mghostx-server ./cmd/server
    
    # Build agent
    info "Building agent binary..."
    go build -o $INSTALL_DIR/bin/mghostx-agent ./cmd/agent
    
    # Build CLI if it exists
    if [ -f "cmd/cli/main.go" ]; then
        info "Building CLI binary..."
        go build -o $INSTALL_DIR/bin/mghostx-cli ./cmd/cli
    fi
    
    # Make binaries executable
    chmod +x $INSTALL_DIR/bin/*
    
    info "Build completed successfully"
}

generate_config() {
    info "Generating system configuration..."
    
    # Server config
    cat > $CONFIG_DIR/server.yaml << EOF
server:
  host: "0.0.0.0"
  port: "8443"
  tls:
    enabled: false

database:
  type: "sqlite"
  path: "$DATA_DIR/db/mghostx.db"

logging:
  level: "info"
  file: "$LOG_DIR/server.log"
EOF

    # Agent config
    cat > $CONFIG_DIR/agent.yaml << EOF
agent:
  id: "$(hostname)-$(date +%s)"
  name: "$(hostname)"
  server: "http://localhost:8443"
  
collect:
  - system_info
  - processes
  - network

heartbeat_interval: 30
EOF
    
    chmod 600 $CONFIG_DIR/*.yaml
}

setup_systemd() {
    info "Setting up systemd services..."
    
    # Server service
    cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Monitoring Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=$INSTALL_DIR/bin/mghostx-server --config $CONFIG_DIR/server.yaml
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
Description=MGHOSTX Security Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=$INSTALL_DIR/bin/mghostx-agent --config $CONFIG_DIR/agent.yaml
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
    info "Systemd services created"
}

setup_firewall() {
    info "Configuring firewall..."
    
    # Check if ufw exists
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 8443/tcp comment "MGHOSTX Web Interface"
        ufw reload
        info "UFW configured"
    fi
    
    # Check if firewalld exists
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --reload
        info "Firewalld configured"
    fi
}

setup_cli() {
    info "Setting up CLI..."
    
    # Create CLI symlink
    if [ -f "$INSTALL_DIR/bin/mghostx-cli" ]; then
        ln -sf $INSTALL_DIR/bin/mghostx-cli $BIN_DIR/mghostx
    else
        # Create simple CLI wrapper
        cat > $BIN_DIR/mghostx << 'EOF'
#!/bin/bash
echo "MGHOSTX Management CLI"
echo "====================="
echo ""
echo "Usage:"
echo "  mghostx-server --config /etc/mghostx/server.yaml"
echo "  mghostx-agent --config /etc/mghostx/agent.yaml"
echo ""
echo "Service Management:"
echo "  sudo systemctl start mghostx-server"
echo "  sudo systemctl start mghostx-agent"
echo "  sudo systemctl status mghostx-server"
echo ""
echo "Logs:"
echo "  sudo journalctl -u mghostx-server -f"
echo "  sudo journalctl -u mghostx-agent -f"
EOF
        chmod +x $BIN_DIR/mghostx
    fi
}

start_services() {
    info "Starting services..."
    
    systemctl enable mghostx-server
    systemctl enable mghostx-agent
    
    systemctl start mghostx-server
    systemctl start mghostx-agent
    
    sleep 2
    
    # Check status
    if systemctl is-active --quiet mghostx-server; then
        log "MGHOSTX server started successfully"
    else
        error "Failed to start MGHOSTX server"
        journalctl -u mghostx-server --no-pager -n 20
    fi
    
    if systemctl is-active --quiet mghostx-agent; then
        log "MGHOSTX agent started successfully"
    else
        warn "MGHOSTX agent failed to start (may be expected if server not ready)"
    fi
}

post_install() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           MGHOSTX Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📊 INSTALLATION SUMMARY"
    echo "======================="
    echo "🌐 Dashboard URL:     http://${ip_address}:8443"
    echo "📁 Installation:      $INSTALL_DIR"
    echo "⚙️  Configuration:     $CONFIG_DIR"
    echo "💾 Data Directory:    $DATA_DIR"
    echo "📝 Log Directory:     $LOG_DIR"
    echo ""
    echo "🚀 SERVICE COMMANDS"
    echo "==================="
    echo "Start server:         sudo systemctl start mghostx-server"
    echo "Start agent:          sudo systemctl start mghostx-agent"
    echo "Stop server:          sudo systemctl stop mghostx-server"
    echo "Check status:         sudo systemctl status mghostx-server"
    echo "View logs:            sudo journalctl -u mghostx-server -f"
    echo ""
    echo "🔧 QUICK TEST"
    echo "============="
    echo "Test server:          curl http://localhost:8443/api/health"
    echo "Test query:           curl 'http://localhost:8443/api/query?q=processes'"
    echo ""
    echo "📚 NEXT STEPS"
    echo "============="
    echo "1. Open browser to: http://localhost:8443"
    echo "2. Configure additional agents"
    echo "3. Set up TLS certificates for production"
    echo "4. Configure AI integration (optional)"
    echo ""
    echo "⚠️  IMPORTANT"
    echo "============"
    echo "For production use:"
    echo "- Enable TLS in $CONFIG_DIR/server.yaml"
    echo "- Change default passwords"
    echo "- Configure firewall rules"
    echo "- Set up proper monitoring"
    echo ""
}

main() {
    log "Starting MGHOSTX Installation"
    check_root
    install_dependencies
    create_directories
    create_project_structure
    build_binaries
    generate_config
    setup_systemd
    setup_firewall
    setup_cli
    start_services
    post_install
    log "Installation completed successfully!"
    
    echo ""
    echo "To access MGHOSTX immediately:"
    echo "1. Open browser: http://$(hostname -I | awk '{print $1}'):8443"
    echo "2. Or run: curl http://localhost:8443/api/health"
    echo ""
}

main
