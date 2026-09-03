package main

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

type claimsKey struct{}

var jwksCache sync.Map // kid → *rsa.PublicKey

func fetchPublicKey(jwksURL, kid string) (*rsa.PublicKey, error) {
	resp, err := http.Get(jwksURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var set struct {
		Keys []struct {
			Kid string `json:"kid"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, err
	}
	for _, k := range set.Keys {
		if k.Kid == kid {
			nBytes, _ := base64.RawURLEncoding.DecodeString(k.N)
			eBytes, _ := base64.RawURLEncoding.DecodeString(k.E)
			pub := &rsa.PublicKey{
				N: new(big.Int).SetBytes(nBytes),
				E: int(new(big.Int).SetBytes(eBytes).Int64()),
			}
			jwksCache.Store(kid, pub)
			return pub, nil
		}
	}
	return nil, fmt.Errorf("kid %q not found in JWKS", kid)
}

func jwtValidationMiddleware(jwksURL string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenStr := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if tokenStr == "" {
				http.Error(w, `{"error":"missing_token"}`, http.StatusUnauthorized)
				return
			}
			// Parse without verification first to get the kid
			unverified, _, err := jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})
			if err != nil {
				http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
				return
			}
			kid, _ := unverified.Header["kid"].(string)

			// Try cached key, re-fetch on failure (handles key rotation)
			pub, _ := jwksCache.Load(kid)
			if pub == nil {
				pub, err = fetchPublicKey(jwksURL, kid)
				if err != nil {
					http.Error(w, `{"error":"jwks_unavailable"}`, http.StatusUnauthorized)
					return
				}
			}

			token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
				if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
					return nil, fmt.Errorf("unexpected alg: %v", t.Header["alg"])
				}
				return pub.(*rsa.PublicKey), nil
			})
			if err != nil {
				// Key may have rotated — re-fetch once
				newPub, ferr := fetchPublicKey(jwksURL, kid)
				if ferr != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
				token, err = jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
					return newPub, nil
				})
				if err != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
			}

			claims := token.Claims.(*WSO2Claims)
			ctx := context.WithValue(r.Context(), claimsKey{}, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
