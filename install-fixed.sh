
#!/bin/bash

# MGHOSTX Fixed Installer
set -e

echo "🔧 MGHOSTX Installation"

# Install Go if needed
if ! command -v go &> /dev/null; then
    pacman -Sy --noconfirm go
fi

# Create directories
mkdir -p /opt/mghostx /etc/mghostx /var/log/mghostx /var/lib/mghostx

# Go to source directory
cd /tmp/xmghostx

# Fix any issues in source
if [ -f "cmd/agent/main.go" ]; then
    # Remove unused variable
    sed -i '/configFile := flag\.String/d' cmd/agent/main.go
    # Fix missing strings import
    sed -i 's/strings\.NewReader/bytes\.NewReader/g' cmd/agent/main.go
fi

# Build
echo "Building..."
go build -buildvcs=false -o /opt/mghostx/mghostx-server ./cmd/server
go build -buildvcs=false -o /opt/mghostx/mghostx-agent ./cmd/agent
chmod +x /opt/mghostx/mghostx-*

# Create config
cat > /etc/mghostx/server.yaml << EOF
server:
  port: 8443
  host: 0.0.0.0
EOF

# Create systemd service
cat > /etc/systemd/system/mghostx-server.service << EOF
[Unit]
Description=MGHOSTX Security Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mghostx
ExecStart=/opt/mghostx/mghostx-server --port 8443
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/mghostx-agent.service << EOF
[Unit]
Description=MGHOSTX Security Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mghostx
ExecStart=/opt/mghostx/mghostx-agent --server http://localhost:8443
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mghostx-server
systemctl enable --now mghostx-agent

echo "✅ Installation complete!"
echo "🌐 Access: http://localhost:8443"
echo "📊 Status: systemctl status mghostx-server"
