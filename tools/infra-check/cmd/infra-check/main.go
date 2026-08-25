package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	var err error
	switch os.Args[1] {
	case "health", "version":
		if len(os.Args) != 3 {
			usage()
		}
		path := "/ready"
		if os.Args[1] == "version" {
			path = "/version"
		}
		var req *http.Request
		req, err = http.NewRequestWithContext(ctx, http.MethodGet, os.Args[2]+path, nil)
		if err == nil {
			var res *http.Response
			res, err = (&http.Client{Timeout: 10 * time.Second}).Do(req)
			if err == nil {
				defer res.Body.Close()
				if res.StatusCode != http.StatusOK {
					err = fmt.Errorf("endpoint returned %s", res.Status)
				} else if path == "/version" {
					var version map[string]string
					err = json.NewDecoder(res.Body).Decode(&version)
					if err == nil {
						fmt.Println(version["version"])
					}
				} else {
					fmt.Println("ready")
				}
			}
		}
	case "deployment":
		if len(os.Args) != 4 {
			usage()
		}
		cmd := exec.CommandContext(ctx, "kubectl", "-n", os.Args[2], "rollout", "status", "deployment/"+os.Args[3], "--timeout=10s")
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		err = cmd.Run()
	case "rollback":
		if len(os.Args) != 4 {
			usage()
		}
		cmd := exec.CommandContext(ctx, "kubectl", "-n", os.Args[2], "rollout", "undo", "deployment/"+os.Args[3])
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		err = cmd.Run()
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: infra-check health|version URL | deployment|rollback NAMESPACE DEPLOYMENT")
	os.Exit(2)
}
