package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

type ServerConfig struct {
	Host string `json:"host"`
	Port string `json:"port"`
}

type HealthResponse struct {
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
	Version   string `json:"version"`
}

type Process struct {
	PID  int    `json:"pid"`
	Name string `json:"name"`
	User string `json:"user"`
}

func main() {
	configPath := flag.String("config", "config/server.yaml", "Config file path")
	port := flag.String("port", "8443", "Server port")
	flag.Parse()

	config := ServerConfig{
		Host: "0.0.0.0",
		Port: *port,
	}

	// Basic HTTP server
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		html := `<!DOCTYPE html>
<html>
<head>
    <title>MGHOSTX Security Platform</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                  color: white; padding: 40px; border-radius: 15px; margin-bottom: 30px; }
        .card { background: white; padding: 25px; border-radius: 10px; 
                box-shadow: 0 4px 6px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .btn { background: #4299e1; color: white; padding: 12px 24px; 
               border: none; border-radius: 6px; cursor: pointer; text-decoration: none; 
               display: inline-block; margin: 5px; }
        .btn:hover { background: #3182ce; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 MGHOSTX Security Platform</h1>
        <p>Real-time security monitoring & incident response</p>
        <p>Server: %s | Port: %s | Config: %s</p>
    </div>
    
    <div class="card">
        <h2>🚀 Quick Actions</h2>
        <a href="/api/health" class="btn">Health Check</a>
        <a href="/api/processes" class="btn">View Processes</a>
        <a href="/api/system" class="btn">System Info</a>
        <a href="/dashboard" class="btn">Dashboard</a>
    </div>
    
    <div class="card">
        <h2>📊 System Status</h2>
        <p>✅ Server: Running</p>
        <p>🔗 Endpoints: 1 connected</p>
        <p>🚨 Active Alerts: 0</p>
        <p>⏰ Uptime: 100%%</p>
    </div>
    
    <div class="card">
        <h2>🛠️ Commands</h2>
        <code>curl http://%s:%s/api/health</code><br>
        <code>curl http://%s:%s/api/processes</code>
    </div>
</body>
</html>`
		fmt.Fprintf(w, html, config.Host, config.Port, *configPath, config.Host, config.Port, config.Host, config.Port)
	})

	http.HandleFunc("/dashboard", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<!DOCTYPE html>
<html>
<head>
    <title>MGHOSTX Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #434343 0%, #000000 100%); 
                  color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card h3 { margin-top: 0; color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .process-list { max-height: 300px; overflow-y: auto; }
        .process-item { padding: 8px; border-bottom: 1px solid #eee; }
        .process-item:hover { background: #f8f9fa; }
        .status-good { color: #38a169; }
        .status-warning { color: #d69e2e; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 MGHOSTX Security Dashboard</h1>
            <p>Comprehensive security monitoring and analytics</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>📈 System Overview</h3>
                <p><strong>Hostname:</strong> <span id="hostname">Loading...</span></p>
                <p><strong>OS:</strong> <span id="os">Loading...</span></p>
                <p><strong>Uptime:</strong> <span id="uptime">Loading...</span></p>
                <p><strong>Status:</strong> <span class="status-good">● Operational</span></p>
            </div>
            
            <div class="card">
                <h3>🔗 Connected Agents</h3>
                <div id="agents">Loading agents...</div>
            </div>
            
            <div class="card">
                <h3>🚨 Security Alerts</h3>
                <div id="alerts">No active alerts</div>
            </div>
        </div>
        
        <div class="card" style="margin-top: 20px;">
            <h3>🖥️ Running Processes</h3>
            <div class="process-list" id="processes">Loading processes...</div>
        </div>
    </div>
    
    <script>
        async function loadData() {
            try {
                // Load health status
                const healthRes = await fetch('/api/health');
                const health = await healthRes.json();
                document.getElementById('hostname').textContent = window.location.hostname;
                document.getElementById('os').textContent = navigator.platform;
                document.getElementById('uptime').textContent = new Date(health.timestamp).toLocaleTimeString();
                
                // Load processes
                const procRes = await fetch('/api/processes');
                const processes = await procRes.json();
                const processList = document.getElementById('processes');
                processList.innerHTML = processes.map(p => 
                    `<div class="process-item">
                        <strong>${p.name}</strong> (PID: ${p.pid}) - ${p.user}
                    </div>`
                ).join('');
                
                // Load agents
                const agentsRes = await fetch('/api/agents');
                const agents = await agentsRes.json();
                document.getElementById('agents').innerHTML = 
                    agents.map(a => `<p>${a.name} - ${a.status}</p>`).join('');
                    
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }
        
        // Load data on page load
        loadData();
        
        // Refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>`)
	})

	http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		response := HealthResponse{
			Status:    "healthy",
			Timestamp: time.Now().Format(time.RFC3339),
			Version:   "1.0.0",
		}
		json.NewEncoder(w).Encode(response)
	})

	http.HandleFunc("/api/processes", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		processes := []Process{
			{PID: 1, Name: "systemd", User: "root"},
			{PID: 100, Name: "sshd", User: "root"},
			{PID: 200, Name: "nginx", User: "nginx"},
			{PID: 300, Name: "postgres", User: "postgres"},
			{PID: 400, Name: "docker", User: "root"},
			{PID: 500, Name: "mghostx-agent", User: "root"},
		}
		json.NewEncoder(w).Encode(processes)
	})

	http.HandleFunc("/api/system", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		systemInfo := map[string]interface{}{
			"hostname":    getHostname(),
			"os":          "linux",
			"arch":        "amd64",
			"cpu_cores":   4,
			"memory_mb":   8192,
			"timestamp":   time.Now().Format(time.RFC3339),
			"server_port": config.Port,
		}
		json.NewEncoder(w).Encode(systemInfo)
	})

	http.HandleFunc("/api/agents", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		agents := []map[string]string{
			{"id": "agent-001", "name": "localhost", "status": "connected", "last_seen": time.Now().Format("15:04:05")},
		}
		json.NewEncoder(w).Encode(agents)
	})

	addr := fmt.Sprintf("%s:%s", config.Host, config.Port)
	log.Printf("🚀 MGHOSTX Server starting on http://%s", addr)
	log.Printf("📊 Dashboard: http://%s", addr)
	log.Printf("🩺 Health: http://%s/api/health", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}
