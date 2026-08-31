package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

type tokenRecord struct {
	ClientID  string
	Scope     string
	IssuedAt  time.Time
	ExpiresIn int
}

var (
	// In-memory token store — keyed by token string
	tokenStore sync.Map
	// Registered clients: clientID -> clientSecret (placeholders — replace for testing)
	clients = map[string]string{
		"test-client": "test-secret",
	}
)

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler)
	log.Println("listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := r.ParseForm(); err != nil {
		oauthError(w, "invalid_request", http.StatusBadRequest)
		return
	}

	clientID, clientSecret, ok := r.BasicAuth()
	if !ok {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	if !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}

	grantType := r.FormValue("grant_type")
	if grantType != "client_credentials" {
		oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
		return
	}

	scope := r.FormValue("scope")
	token := generateToken()
	tokenStore.Store(token, tokenRecord{
		ClientID:  clientID,
		Scope:     scope,
		IssuedAt:  time.Now(),
		ExpiresIn: 3600,
	})

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"access_token": token,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

func validateClient(id, secret string) bool {
	expected, ok := clients[id]
	return ok && expected == secret
}

func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}
