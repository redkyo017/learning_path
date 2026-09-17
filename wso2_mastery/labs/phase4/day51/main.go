package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

type OAuthGrantHandler interface {
	CanHandle(grantType string) bool
	ValidateGrant(req *TokenRequest) error
	IssueToken(req *TokenRequest) (*TokenResponse, error)
}

type TokenRequest struct {
	GrantType    string
	ClientID     string
	ClientSecret string
	Username     string
	Password     string
	Scope        string
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	Scope       string `json:"scope,omitempty"`
}

// ClientCredentialsHandler — WSO2 class: ClientCredentialsGrantHandler
type ClientCredentialsHandler struct {
	validClients map[string]string
}

func NewClientCredentialsHandler() *ClientCredentialsHandler {
	return &ClientCredentialsHandler{validClients: map[string]string{
		"demo-client-id": "demo-secret",
	}}
}
func (h *ClientCredentialsHandler) CanHandle(gt string) bool { return gt == "client_credentials" }
func (h *ClientCredentialsHandler) ValidateGrant(req *TokenRequest) error {
	if secret, ok := h.validClients[req.ClientID]; !ok || secret != req.ClientSecret {
		return fmt.Errorf("invalid_client")
	}
	return nil
}
func (h *ClientCredentialsHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	return &TokenResponse{
		AccessToken: fmt.Sprintf("cc-tok-%d", time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 3600, Scope: req.Scope,
	}, nil
}

// ROPCHandler — WSO2 class: PasswordGrantHandler
type ROPCHandler struct {
	validUsers map[string]string
}

func NewROPCHandler() *ROPCHandler {
	return &ROPCHandler{validUsers: map[string]string{"alice": "pass123", "bob": "pass456"}}
}
func (h *ROPCHandler) CanHandle(gt string) bool { return gt == "password" }
func (h *ROPCHandler) ValidateGrant(req *TokenRequest) error {
	if pass, ok := h.validUsers[req.Username]; !ok || pass != req.Password {
		return fmt.Errorf("invalid_grant")
	}
	return nil
}
func (h *ROPCHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	return &TokenResponse{
		AccessToken: fmt.Sprintf("ropc-%s-%d", req.Username, time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 3600, Scope: req.Scope,
	}, nil
}

// DeviceGrant — custom grant type: urn:ietf:params:oauth:grant-type:device_code
// Simplified for the lab — no polling, just validates a pre-approved device_code.
type DeviceGrant struct {
	approvedCodes map[string]string // device_code → username
}

func NewDeviceGrant() *DeviceGrant {
	return &DeviceGrant{approvedCodes: map[string]string{"device-abc": "carol"}}
}
func (h *DeviceGrant) CanHandle(gt string) bool {
	return gt == "urn:ietf:params:oauth:grant-type:device_code"
}
func (h *DeviceGrant) ValidateGrant(req *TokenRequest) error {
	// device_code is passed in the password field for simplicity
	if _, ok := h.approvedCodes[req.Password]; !ok {
		return fmt.Errorf("authorization_pending")
	}
	return nil
}
func (h *DeviceGrant) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	user := h.approvedCodes[req.Password]
	return &TokenResponse{
		AccessToken: fmt.Sprintf("device-%s-%d", user, time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 900,
	}, nil
}

type TokenEndpoint struct {
	handlers []OAuthGrantHandler
}

func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.ParseForm()
	req := &TokenRequest{
		GrantType:    r.FormValue("grant_type"),
		ClientID:     r.FormValue("client_id"),
		ClientSecret: r.FormValue("client_secret"),
		Username:     r.FormValue("username"),
		Password:     r.FormValue("password"),
		Scope:        r.FormValue("scope"),
	}
	if req.GrantType == "" {
		writeTokenError(w, "invalid_request", "grant_type required", http.StatusBadRequest)
		return
	}
	for _, h := range e.handlers {
		if !h.CanHandle(req.GrantType) {
			continue
		}
		if err := h.ValidateGrant(req); err != nil {
			status := http.StatusUnauthorized
			if err.Error() == "invalid_request" || err.Error() == "authorization_pending" {
				status = http.StatusBadRequest
			}
			writeTokenError(w, err.Error(), "", status)
			return
		}
		tok, err := h.IssueToken(req)
		if err != nil {
			writeTokenError(w, "server_error", err.Error(), http.StatusInternalServerError)
			return
		}
		slog.Info("token issued", "grant", req.GrantType, "client", req.ClientID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tok)
		return
	}
	writeTokenError(w, "unsupported_grant_type", req.GrantType, http.StatusBadRequest)
}

func writeTokenError(w http.ResponseWriter, code, desc string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code, "error_description": desc})
}

func main() {
	ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
		NewClientCredentialsHandler(),
		NewROPCHandler(),
		NewDeviceGrant(),
	}}
	mux := http.NewServeMux()
	mux.Handle("/oauth2/token", ep)
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"status":"UP"}`))
	})
	fmt.Println("Custom grant handler blueprint on :8091")
	fmt.Println("Test: curl -X POST http://localhost:8091/oauth2/token -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret'")
	http.ListenAndServe(":8091", mux)
}
