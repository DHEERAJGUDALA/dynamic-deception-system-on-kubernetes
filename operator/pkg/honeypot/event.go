package honeypot

import (
	"encoding/json"
	"time"
)

// Event represents a honeypot interaction event
type Event struct {
	ID          string                 `json:"id"`
	Timestamp   time.Time              `json:"timestamp"`
	Type        EventType              `json:"type"`
	Source      Source                 `json:"source"`
	Honeypot    HoneypotInfo           `json:"honeypot"`
	Details     map[string]interface{} `json:"details"`
	Severity    Severity               `json:"severity"`
	RawData     []byte                 `json:"raw_data,omitempty"`
}

// EventType categorizes the type of interaction
type EventType string

const (
	EventTypeSSHLogin          EventType = "ssh_login"
	EventTypeSSHCommand        EventType = "ssh_command"
	EventTypeHTTPRequest       EventType = "http_request"
	EventTypeSQLQuery          EventType = "sql_query"
	EventTypeSQLInjection      EventType = "sql_injection"
	EventTypeSMTPConnection    EventType = "smtp_connection"
	EventTypePortScan          EventType = "port_scan"
	EventTypeBruteForce        EventType = "brute_force"
	EventTypeCredentialAccess  EventType = "credential_access"
)

// Source contains information about the attacker
type Source struct {
	IP        string `json:"ip"`
	Port      int    `json:"port"`
	Country   string `json:"country,omitempty"`
	City      string `json:"city,omitempty"`
	ASN       string `json:"asn,omitempty"`
	UserAgent string `json:"user_agent,omitempty"`
}

// HoneypotInfo identifies which honeypot captured the event
type HoneypotInfo struct {
	Type      string `json:"type"`
	Name      string `json:"name"`
	Namespace string `json:"namespace"`
	Port      int    `json:"port"`
}

// Severity indicates the alert level
type Severity string

const (
	SeverityLow      Severity = "low"
	SeverityMedium   Severity = "medium"
	SeverityHigh     Severity = "high"
	SeverityCritical Severity = "critical"
)

// ToJSON serializes the event to JSON
func (e *Event) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// FromJSON deserializes an event from JSON
func FromJSON(data []byte) (*Event, error) {
	var event Event
	if err := json.Unmarshal(data, &event); err != nil {
		return nil, err
	}
	return &event, nil
}

// ClassifySeverity determines severity based on event type and details
func ClassifySeverity(eventType EventType, details map[string]interface{}) Severity {
	switch eventType {
	case EventTypeSQLInjection:
		return SeverityCritical
	case EventTypeCredentialAccess:
		return SeverityCritical
	case EventTypeBruteForce:
		return SeverityHigh
	case EventTypeSSHCommand:
		// Check for dangerous commands
		if cmd, ok := details["command"].(string); ok {
			if containsDangerousCommand(cmd) {
				return SeverityHigh
			}
		}
		return SeverityMedium
	case EventTypeHTTPRequest:
		// Check for suspicious paths
		if path, ok := details["path"].(string); ok {
			if isSuspiciousPath(path) {
				return SeverityMedium
			}
		}
		return SeverityLow
	default:
		return SeverityLow
	}
}

func containsDangerousCommand(cmd string) bool {
	dangerous := []string{"rm -rf", "wget", "curl", "chmod", "nc ", "netcat", "/etc/passwd", "/etc/shadow"}
	for _, d := range dangerous {
		if contains(cmd, d) {
			return true
		}
	}
	return false
}

func isSuspiciousPath(path string) bool {
	suspicious := []string{"/admin", "/wp-admin", "/phpmyadmin", "/.env", "/config", "/backup"}
	for _, s := range suspicious {
		if contains(path, s) {
			return true
		}
	}
	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
