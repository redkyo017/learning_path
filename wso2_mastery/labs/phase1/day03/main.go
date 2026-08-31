package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"
)

type tokenRecord struct {
	ClientID  string
	Scope     string
	IssuedAt  time.Time
	ExpiresIn int
}

type codeRecord struct {
	ClientID      string
	RedirectURI   string
	Scope         string
	CodeChallenge string // PKCE: BASE64URL(SHA256(code_verifier))
	IssuedAt      time.Time
}

var (
	tokenStore sync.Map
	codeStore  sync.Map
	clients    = map[string]string{
		"test-client": "test-secret",
	}
)

func main() {
	http.HandleFunc("/oauth2/authorize", authorizeHandler)
	http.HandleFunc("/oauth2/token", tokenHandler)
	log.Println("listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}

func authorizeHandler(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if q.Get("response_type") != "code" {
		// Ruling 1 fix: pass r as second argument so redirectError can call http.Redirect
		redirectError(w, r, q.Get("redirect_uri"), "unsupported_response_type", q.Get("state"))
		return
	}
	clientID := q.Get("client_id")
	if _, ok := clients[clientID]; !ok {
		http.Error(w, "unknown client", http.StatusBadRequest)
		return
	}
	code := generateToken()
	codeStore.Store(code, codeRecord{
		ClientID:      clientID,
		RedirectURI:   q.Get("redirect_uri"),
		Scope:         q.Get("scope"),
		CodeChallenge: q.Get("code_challenge"),
		IssuedAt:      time.Now(),
	})
	redirectTo := q.Get("redirect_uri") + "?code=" + code
	if state := q.Get("state"); state != "" {
		redirectTo += "&state=" + url.QueryEscape(state)
	}
	http.Redirect(w, r, redirectTo, http.StatusFound)
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.ParseForm()
	switch r.FormValue("grant_type") {
	case "client_credentials":
		handleClientCredentials(w, r)
	case "authorization_code":
		handleAuthCode(w, r)
	default:
		oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
	}
}

func handleClientCredentials(w http.ResponseWriter, r *http.Request) {
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	issueToken(w, clientID, r.FormValue("scope"))
}

func handleAuthCode(w http.ResponseWriter, r *http.Request) {
	code := r.FormValue("code")
	val, ok := codeStore.LoadAndDelete(code) // single-use: deleted on first access
	if !ok {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	rec := val.(codeRecord)
	if time.Since(rec.IssuedAt) > 10*time.Minute {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	if r.FormValue("redirect_uri") != rec.RedirectURI {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	// PKCE verification: if a challenge was stored, the verifier must match
	if rec.CodeChallenge != "" {
		verifier := r.FormValue("code_verifier")
		h := sha256.Sum256([]byte(verifier))
		challenge := base64.RawURLEncoding.EncodeToString(h[:])
		if challenge != rec.CodeChallenge {
			oauthError(w, "invalid_grant", http.StatusBadRequest)
			return
		}
	}
	issueToken(w, rec.ClientID, rec.Scope)
}

func issueToken(w http.ResponseWriter, clientID, scope string) {
	token := generateToken()
	tokenStore.Store(token, tokenRecord{
		ClientID:  clientID,
		Scope:     scope,
		IssuedAt:  time.Now(),
		ExpiresIn: 3600,
	})
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]any{
		"access_token": token,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

// redirectError sends an OAuth2 error as a redirect to redirect_uri.
// If redirect_uri is empty, it falls back to a plain 400 response.
// Ruling 1: r *http.Request is required so http.Redirect can set the Location header properly.
func redirectError(w http.ResponseWriter, r *http.Request, redirectURI, errCode, state string) {
	if redirectURI == "" {
		http.Error(w, errCode, http.StatusBadRequest)
		return
	}
	u := redirectURI + "?error=" + errCode
	if state != "" {
		u += "&state=" + url.QueryEscape(state)
	}
	http.Redirect(w, r, u, http.StatusFound)
}

func validateClient(id, secret string) bool {
	exp, ok := clients[id]
	return ok && exp == secret
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
