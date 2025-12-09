#!/bin/bash

echo "Setting up MGHOSTX project..."

# Create directories
mkdir -p cmd/{server,agent,cli} config scripts internal/{api,collectors,models}

# Create go.mod
cat > go.mod << 'EOF'
module github.com/VN-KEO/xmghostx

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/sirupsen/logrus v1.9.3
    gopkg.in/yaml.v3 v3.0.1
)
EOF

# Create server
cat > cmd/server/main.go << 'EOF'
package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "log"
    "net/http"
    "time"
)

func main() {
    port := flag.String("port", "8443", "Server port")
    flag.Parse()

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "<h1>MGHOSTX Server</h1><p>Running on port %s</p>", *port)
    })

    http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(map[string]string{
            "status": "ok",
            "time":   time.Now().Format(time.RFC3339),
        })
    })

    log.Printf("Server starting on :%s", *port)
    http.ListenAndServe(":"+*port, nil)
}
EOF

# Create agent
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

    fmt.Printf("Agent connecting to %s\n", *server)

    ticker := time.NewTicker(30 * time.Second)
    for range ticker.C {
        log.Printf("Heartbeat sent to %s", *server)
    }
}
EOF

# Create CLI
cat > cmd/cli/main.go << 'EOF'
package main

import (
    "flag"
    "fmt"
)

func main() {
    query := flag.String("query", "", "Query to run")
    flag.Parse()

    if *query == "" {
        fmt.Println("MGHOSTX CLI - Use --query <type>")
    } else {
        fmt.Printf("Running query: %s\n", *query)
    }
}
EOF

# Download dependencies
go mod tidy

echo "Setup complete! Build with:"
echo "go build -o mghostx-server ./cmd/server"
echo "go build -o mghostx-agent ./cmd/agent"
