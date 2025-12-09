#!/bin/bash
# Quick setup script for empty MGHOSTX repository

echo "Setting up MGHOSTX project structure..."

# Create basic structure
mkdir -p cmd/{server,agent,cli} config scripts internal/{api,collectors,models}

# Initialize go module
go mod init github.com/VN-KEO/xmghostx

# Create basic files
cat > cmd/server/main.go << 'EOF'
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprint(w, "<h1>MGHOSTX Server</h1><p>Running!</p>")
    })
    
    fmt.Println("Server starting on :8080")
    http.ListenAndServe(":8080", nil)
}
EOF

cat > cmd/agent/main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("MGHOSTX Agent - Work in progress")
}
EOF

cat > cmd/cli/main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("MGHOSTX CLI - Work in progress")
}
EOF

# Create config
cat > config/server.example.yaml << 'EOF'
server:
  port: 8443
  host: "0.0.0.0"
EOF

# Create scripts directory with installer
mkdir -p scripts
cat > scripts/install.sh << 'EOF'
#!/bin/bash
echo "MGHOSTX installer - clone and build"
git clone https://github.com/VN-KEO/xmghostx.git
cd xmghostx
go build -o mghostx-server ./cmd/server
echo "Build complete! Run: ./mghostx-server"
EOF

chmod +x scripts/*.sh

# Create README
cat > README.md << 'EOF'
# MGHOSTX Security Platform

A modern security monitoring and incident response platform.

## Quick Start

```bash
# Clone and build
git clone https://github.com/VN-KEO/xmghostx.git
cd xmghostx
go build -o mghostx-server ./cmd/server

# Run server
./mghostx-server
