package utils

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
)

// ResourceProfile defines resource constraints for a profile
type ResourceProfile struct {
	MemoryRequest string
	MemoryLimit   string
	CPURequest    string
	CPULimit      string
}

// Profiles contains resource profiles for different configurations
var Profiles = map[string]ResourceProfile{
	"light": {
		MemoryRequest: "32Mi",
		MemoryLimit:   "64Mi",
		CPURequest:    "25m",
		CPULimit:      "100m",
	},
	"medium": {
		MemoryRequest: "64Mi",
		MemoryLimit:   "128Mi",
		CPURequest:    "50m",
		CPULimit:      "200m",
	},
	"heavy": {
		MemoryRequest: "128Mi",
		MemoryLimit:   "256Mi",
		CPURequest:    "100m",
		CPULimit:      "500m",
	},
}

// GetResourceRequirements returns Kubernetes resource requirements for a profile
func GetResourceRequirements(profile string) corev1.ResourceRequirements {
	p, ok := Profiles[profile]
	if !ok {
		p = Profiles["medium"]
	}

	return corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceMemory: resource.MustParse(p.MemoryRequest),
			corev1.ResourceCPU:    resource.MustParse(p.CPURequest),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceMemory: resource.MustParse(p.MemoryLimit),
			corev1.ResourceCPU:    resource.MustParse(p.CPULimit),
		},
	}
}

// GenerateID creates a unique identifier
func GenerateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// GenerateToken creates a random token of specified length
func GenerateToken(length int) string {
	b := make([]byte, length)
	rand.Read(b)
	return hex.EncodeToString(b)[:length]
}

// GetEnvOrDefault returns environment variable value or default
func GetEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GetEnvAsInt returns environment variable as integer or default
func GetEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return defaultValue
}

// GetEnvAsDuration returns environment variable as duration or default
func GetEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if d, err := time.ParseDuration(value); err == nil {
			return d
		}
	}
	return defaultValue
}

// IsPrivateIP checks if an IP address is private
func IsPrivateIP(ip string) bool {
	parsedIP := net.ParseIP(ip)
	if parsedIP == nil {
		return false
	}

	privateRanges := []string{
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
		"127.0.0.0/8",
	}

	for _, cidr := range privateRanges {
		_, network, _ := net.ParseCIDR(cidr)
		if network.Contains(parsedIP) {
			return true
		}
	}
	return false
}

// SanitizeInput removes potentially dangerous characters
func SanitizeInput(input string) string {
	dangerous := []string{";", "|", "&", "$", "`", "(", ")", "{", "}", "[", "]", "<", ">", "\\"}
	result := input
	for _, char := range dangerous {
		result = strings.ReplaceAll(result, char, "")
	}
	return result
}

// FormatBytes formats bytes to human readable string
func FormatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

// CalculateMemoryLimit calculates memory limit based on profile
func CalculateMemoryLimit(profile string, baseBytes int64) int64 {
	multipliers := map[string]float64{
		"light":  0.5,
		"medium": 1.0,
		"heavy":  2.0,
	}

	multiplier, ok := multipliers[profile]
	if !ok {
		multiplier = 1.0
	}

	return int64(float64(baseBytes) * multiplier)
}

// TimeTrack is a helper for measuring execution time
func TimeTrack(start time.Time, name string) {
	elapsed := time.Since(start)
	fmt.Printf("%s took %s\n", name, elapsed)
}
