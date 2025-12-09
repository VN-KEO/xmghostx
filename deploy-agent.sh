#!/bin/bash

# MGHOSTX Agent Deployment Script

set -e

CONFIG_DIR="./agent-configs"
LOG_FILE="/var/log/mghostx-deploy.log"
REPO_URL="https://github.com/VN-KEO/xmghostx.git"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[+]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[!]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Download agent binary from repository
download_agent() {
    local os=$1
    local arch=$2
    local output_dir=$3
    
    log "Downloading agent for $os-$arch..."
    
    # Try to download from releases
    local release_url="https://github.com/VN-KEO/xmghostx/releases/latest/download/mghostx-agent-$os-$arch"
    
    if curl -s -I "$release_url" | grep -q "200 OK"; then
        curl -L "$release_url" -o "$output_dir/mghostx-agent"
        chmod +x "$output_dir/mghostx-agent"
        log "Agent downloaded from releases"
        return 0
    fi
    
    # Try to build from source
    log "No binary release found, building from source..."
    
    if ! command -v git &> /dev/null; then
        error "Git is required to build from source"
        return 1
    fi
    
    if ! command -v go &> /dev/null; then
        error "Go is required to build from source"
        return 1
    fi
    
    # Clone and build
    local build_dir=$(mktemp -d)
    git clone "$REPO_URL" "$build_dir"
    
    cd "$build_dir"
    
    # Build agent
    if [ -f "Makefile" ]; then
        make agent
    elif [ -f "go.mod" ]; then
        GOOS=$os GOARCH=$arch go build -o "$output_dir/mghostx-agent" ./cmd/agent
    else
        error "Cannot find build files"
        return 1
    fi
    
    # Cleanup
    rm -rf "$build_dir"
    
    if [ -f "$output_dir/mghostx-agent" ]; then
        chmod +x "$output_dir/mghostx-agent"
        log "Agent built successfully"
        return 0
    else
        error "Failed to build agent"
        return 1
    fi
}

# Main deployment function
deploy_agent() {
    local server_url=$1
    local agent_name=$2
    local tags=$3
    
    log "Deploying agent: $agent_name"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Generate agent config
    local config_file="$CONFIG_DIR/$agent_name.yaml"
    
    cat > "$config_file" << EOF
# MGHOSTX Agent Configuration
# Generated: $(date)

agent:
  id: $agent_name-$(uuidgen | cut -c1-8)
  name: "$agent_name"
  tags: [$tags]
  
  server:
    url: $server_url
    insecure_skip_verify: true  # Change to false in production
  
  collectors:
    - system_info
    - processes
    - network
    - filesystem
  
  logging:
    level: info
    file: /var/log/mghostx/agent.log
EOF

    log "Config generated: $config_file"
    echo "To install:"
    echo "1. Download agent binary from: $REPO_URL"
    echo "2. Copy config to /etc/mghostx/agent.yaml"
    echo "3. Run: ./mghostx-agent --config /etc/mghostx/agent.yaml"
}

# Show usage
usage() {
    echo "MGHOSTX Agent Deployment Tool"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --server URL          MGHOSTX server URL (required)"
    echo "  --name NAME           Agent name (required)"
    echo "  --tags TAGS           Comma-separated tags"
    echo "  --download OS ARCH    Download agent binary"
    echo "  --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --server https://192.168.1.100:8443 --name web01 --tags web,production"
    echo "  $0 --download linux amd64"
    echo ""
    echo "Repository: $REPO_URL"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_URL="$2"
            shift 2
            ;;
        --name)
            AGENT_NAME="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --download)
            DOWNLOAD_OS="$2"
            DOWNLOAD_ARCH="$3"
            shift 3
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main
if [ -n "$DOWNLOAD_OS" ] && [ -n "$DOWNLOAD_ARCH" ]; then
    download_agent "$DOWNLOAD_OS" "$DOWNLOAD_ARCH" "."
elif [ -n "$SERVER_URL" ] && [ -n "$AGENT_NAME" ]; then
    deploy_agent "$SERVER_URL" "$AGENT_NAME" "${TAGS:-default}"
else
    usage
    exit 1
fi
