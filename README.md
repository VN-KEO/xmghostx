# MGHOSTX Security Platform

A modern security monitoring and incident response platform.

## 🚀 Quick Start

### 1. Clone and Build
```bash
git clone https://github.com/VN-KEO/xmghostx.git
cd xmghostx
go mod download
go build -o mghostx-server ./cmd/server
go build -o mghostx-agent ./cmd/agent
go build -o mghostx ./cmd/cli
