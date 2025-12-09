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

type AgentConfig struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Server string `json:"server"`
}

type Heartbeat struct {
	AgentID   string                 `json:"agent_id"`
	Timestamp string                 `json:"timestamp"`
	System    map[string]interface{} `json:"system"`
	Processes []Process              `json:"processes"`
}

type Process struct {
	PID  int    `json:"pid"`
	Name string `json:"name"`
	User string `json:"user"`
}

func main() {
	configFile := flag.String("config", "config/agent.yaml", "Config file")
	serverURL := flag.String("server", "http://localhost:8443", "MGHOSTX server URL")
	flag.Parse()

	config := AgentConfig{
		ID:     fmt.Sprintf("%s-%d", getHostname(), time.Now().Unix()),
		Name:   getHostname(),
		Server: *serverURL,
	}

	log.Printf("🤖 MGHOSTX Agent starting")
	log.Printf("🆔 Agent ID: %s", config.ID)
	log.Printf("🔗 Server: %s", config.Server)

	// Initial heartbeat
	sendHeartbeat(config)

	// Periodic heartbeats
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			sendHeartbeat(config)
		}
	}
}

func sendHeartbeat(config AgentConfig) {
	heartbeat := Heartbeat{
		AgentID:   config.ID,
		Timestamp: time.Now().Format(time.RFC3339),
		System:    collectSystemInfo(),
		Processes: collectProcesses(),
	}

	// In a real implementation, we would send this via HTTP POST
	log.Printf("💓 Heartbeat sent to %s", config.Server)
	log.Printf("📊 System: %s, Processes: %d", getHostname(), len(heartbeat.Processes))

	// Try to actually send to server (optional)
	go func() {
		data, _ := json.Marshal(heartbeat)
		http.Post(config.Server+"/api/heartbeat", "application/json", strings.NewReader(string(data)))
	}()
}

func collectSystemInfo() map[string]interface{} {
	return map[string]interface{}{
		"hostname":   getHostname(),
		"os":         "linux",
		"arch":       "amd64",
		"cpu_cores":  4,
		"memory_mb":  8192,
		"load_avg":   []float64{0.1, 0.2, 0.3},
		"uptime":     "1 day, 5:30:00",
		"timestamp":  time.Now().Format(time.RFC3339),
	}
}

func collectProcesses() []Process {
	// Simulate collecting processes
	return []Process{
		{PID: 1, Name: "systemd", User: "root"},
		{PID: 100, Name: "sshd", User: "root"},
		{PID: 200, Name: "bash", User: "user"},
		{PID: 300, Name: "mghostx-agent", User: "root"},
		{PID: 400, Name: "docker", User: "root"},
	}
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}
