#!/bin/bash

# MGHOSTX Quick Start
# One-command deployment for testing and development

set -e

echo "🚀 MGHOSTX Quick Start"
echo "======================"

# Configuration
REPO_URL="https://github.com/VN-KEO/xmghostx.git"
PROJECT_DIR="$PWD/mghostx-quickstart"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create project directory
echo "📁 Creating project directory..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Clone repository if not exists
if [ ! -d ".git" ]; then
    echo "📥 Cloning MGHOSTX repository..."
    git clone "$REPO_URL" .
else
    echo "📥 Updating existing repository..."
    git pull
fi

# Create .env file if not exists
if [ ! -f ".env" ]; then
    echo "⚙️  Creating environment configuration..."
    cat > .env << EOF
# MGHOSTX Quick Start Environment
COMPOSE_PROJECT_NAME=mghostx
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)
OPENAI_API_KEY=your-openai-api-key-here
SERVER_HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')
EOF
fi

# Check for docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo "🐳 Creating Docker Compose configuration..."
    
    # Look for docker-compose file in the repo
    if [ -f "deployment/docker-compose.yml" ]; then
        cp deployment/docker-compose.yml .
    else
        # Create minimal docker-compose
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mghostx-server:
    build: 
      context: .
      dockerfile: docker/server.Dockerfile
    ports:
      - "8443:8443"
      - "9090:9090"
    environment:
      - DATABASE_URL=sqlite:///data/mghostx.db
      - JWT_SECRET=${JWT_SECRET:-$(openssl rand -hex 32)}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - ./data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s

  mghostx-agent:
    build:
      context: .
      dockerfile: docker/agent.Dockerfile
    network_mode: host
    pid: host
    privileged: true
    volumes:
      - /:/host:ro
      - /proc:/host/proc:ro
    environment:
      - MGHOSTX_SERVER_URL=https://localhost:8443
      - MGHOSTX_AGENT_NAME=quickstart-$(hostname)
    depends_on:
      - mghostx-server
EOF
    fi
fi

# Check if we need to build images
echo "🔍 Checking for existing images..."
if docker images | grep -q "mghostx-server"; then
    echo "✅ MGHOSTX images found"
else
    echo "🏗️  Building MGHOSTX images..."
    
    # Check for Dockerfiles
    if [ ! -f "docker/server.Dockerfile" ] && [ -f "Dockerfile" ]; then
        # Use root Dockerfile
        docker build -t mghostx-server -f Dockerfile .
        docker tag mghostx-server mghostx/agent:latest
    else
        # Try to build from source
        if [ -f "Makefile" ]; then
            make docker
        elif [ -f "go.mod" ]; then
            echo "⚠️  Building from source might take a while..."
            docker build -t mghostx/server:latest -f docker/server.Dockerfile .
            docker build -t mghostx/agent:latest -f docker/agent.Dockerfile .
        else
            echo "❌ Cannot find build files. Trying to pull from registry..."
            docker pull ghcr.io/vn-keo/xmghostx-server:latest || true
            docker pull ghcr.io/vn-keo/xmghostx-agent:latest || true
        fi
    fi
fi

# Start services
echo "🚀 Starting MGHOSTX services..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
for i in {1..30}; do
    if docker-compose ps | grep -q "Up"; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Get service information
SERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mghostx-server 2>/dev/null || echo "localhost")

echo ""
echo "✅ MGHOSTX Quick Start Complete!"
echo ""
echo "📊 Services Status:"
docker-compose ps
echo ""
echo "🌐 Access Points:"
echo "   Dashboard:  https://$SERVER_IP:8443"
echo "   Metrics:    http://$SERVER_IP:9090"
echo ""
echo "🔑 Default Credentials:"
echo "   Username:   admin"
echo "   Password:   Check the logs or data/admin_password.txt"
echo ""
echo "📋 Logs:"
echo "   View all logs:    docker-compose logs -f"
echo "   Server logs:      docker-compose logs mghostx-server"
echo "   Agent logs:       docker-compose logs mghostx-agent"
echo ""
echo "⚡ Management:"
echo "   Stop services:    docker-compose down"
echo "   Restart:          docker-compose restart"
echo "   Update:           git pull && docker-compose up -d --build"
echo ""
echo "🔧 Configuration:"
echo "   Edit .env file to change settings"
echo "   Set OPENAI_API_KEY for AI features"
echo ""
echo "🐛 Troubleshooting:"
echo "   If dashboard is not accessible:"
echo "   1. Check if ports 8443 are open: sudo netstat -tulpn | grep 8443"
echo "   2. Check firewall: sudo ufw status"
echo "   3. View logs: docker-compose logs mghostx-server"
echo ""
echo "💡 Next Steps:"
echo "   1. Access the dashboard"
echo "   2. Configure your settings"
echo "   3. Deploy agents to other systems"
echo "   4. Try AI-powered queries!"
echo ""
echo "📚 Documentation: $REPO_URL"
echo ""
