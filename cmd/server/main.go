package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
)

func main() {
	port := flag.String("port", "8443", "Server port")
	config := flag.String("config", "config.yaml", "Config file path")
	flag.Parse()

	fmt.Printf("MGHOSTX Server starting on port %s\n", *port)
	fmt.Printf("Using config: %s\n", *config)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, `
		<!DOCTYPE html>
		<html>
		<head><title>MGHOSTX</title></head>
		<body>
			<h1>MGHOSTX Security Platform</h1>
			<p>Server is running on port %s</p>
			<p><a href="/dashboard">Dashboard</a></p>
			<p><a href="/api/v1/health">Health Check</a></p>
		</body>
		</html>`, *port)
	})

	http.HandleFunc("/dashboard", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `
		<!DOCTYPE html>
		<html>
		<head>
			<title>MGHOSTX Dashboard</title>
			<style>
				body { font-family: Arial, sans-serif; margin: 40px; }
				.header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
				.stats { display: flex; gap: 20px; margin: 20px 0; }
				.stat-box { background: #ecf0f1; padding: 20px; border-radius: 5px; flex: 1; }
			</style>
		</head>
		<body>
			<div class="header">
				<h1>MGHOSTX Dashboard</h1>
				<p>Security Monitoring Platform</p>
			</div>
			<div class="stats">
				<div class="stat-box">
					<h3>Agents</h3>
					<p id="agent-count">Loading...</p>
				</div>
				<div class="stat-box">
					<h3>Alerts</h3>
					<p id="alert-count">0</p>
				</div>
				<div class="stat-box">
					<h3>System Health</h3>
					<p>Good</p>
				</div>
			</div>
			<script>
				// Simple API calls
				fetch('/api/v1/health').then(r => r.json()).then(data => {
					console.log('Health:', data);
				});
			</script>
		</body>
		</html>`)
	})

	http.HandleFunc("/api/v1/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status": "healthy", "service": "mghostx-server"}`)
	})

	log.Printf("Server listening on :%s", *port)
	log.Fatal(http.ListenAndServe(":"+*port, nil))
}
