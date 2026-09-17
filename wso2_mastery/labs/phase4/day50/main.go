package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"
)

// APIHandler mirrors WSO2's org.wso2.carbon.apimgt.gateway.handlers.APIHandler.
// HandleRequest: true = continue chain; false = short-circuit (response already written).
// HandleResponse: called in reverse order after backend responds.
type APIHandler interface {
	HandleRequest(ctx *MessageContext) bool
	HandleResponse(ctx *MessageContext) bool
	Name() string
}

type MessageContext struct {
	Request    *http.Request
	Writer     http.ResponseWriter
	Properties map[string]any
}

type HandlerChain struct {
	handlers []APIHandler
	backend  *httputil.ReverseProxy
}

func NewHandlerChain(backendURL string) *HandlerChain {
	target, _ := url.Parse(backendURL)
	return &HandlerChain{backend: httputil.NewSingleHostReverseProxy(target)}
}

func (c *HandlerChain) Add(h APIHandler) *HandlerChain {
	c.handlers = append(c.handlers, h)
	return c
}

func (c *HandlerChain) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := &MessageContext{Request: r, Writer: w, Properties: make(map[string]any)}
	for _, h := range c.handlers {
		if !h.HandleRequest(ctx) {
			return
		}
	}
	c.backend.ServeHTTP(w, r)
	for i := len(c.handlers) - 1; i >= 0; i-- {
		c.handlers[i].HandleResponse(ctx)
	}
}

// RequestLogHandler — equivalent to WSO2 LogMediator
type RequestLogHandler struct{}

func (h *RequestLogHandler) Name() string { return "RequestLogger" }
func (h *RequestLogHandler) HandleRequest(ctx *MessageContext) bool {
	slog.Info("request", "method", ctx.Request.Method, "path", ctx.Request.URL.Path)
	return true
}
func (h *RequestLogHandler) HandleResponse(ctx *MessageContext) bool { return true }

// APIKeyCheckHandler — equivalent to WSO2 APIKeyValidationHandler
type APIKeyCheckHandler struct {
	validKeys map[string]string // key → tier name
}

func NewAPIKeyCheckHandler() *APIKeyCheckHandler {
	return &APIKeyCheckHandler{validKeys: map[string]string{
		"test-key-gold":   "Gold",
		"test-key-silver": "Silver",
	}}
}

func (h *APIKeyCheckHandler) Name() string { return "APIKeyCheck" }
func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
	key := ctx.Request.Header.Get("X-API-Key")
	tier, ok := h.validKeys[key]
	if !ok {
		ctx.Writer.Header().Set("Content-Type", "application/json")
		ctx.Writer.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(ctx.Writer).Encode(map[string]string{
			"code": "900901", "message": "Invalid Credentials",
		})
		return false
	}
	ctx.Properties["tier"] = tier
	return true
}
func (h *APIKeyCheckHandler) HandleResponse(ctx *MessageContext) bool { return true }

// LatencyTrackerHandler — no WSO2 equivalent; pure observability
type LatencyTrackerHandler struct{}

func (h *LatencyTrackerHandler) Name() string { return "LatencyTracker" }
func (h *LatencyTrackerHandler) HandleRequest(ctx *MessageContext) bool {
	ctx.Properties["reqStart"] = time.Now()
	return true
}
func (h *LatencyTrackerHandler) HandleResponse(ctx *MessageContext) bool {
	if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
		slog.Info("latency", "ms", time.Since(start).Milliseconds(),
			"path", ctx.Request.URL.Path, "tier", ctx.Properties["tier"])
	}
	return true
}

func main() {
	chain := NewHandlerChain("http://httpbin.org")
	chain.Add(&RequestLogHandler{})
	chain.Add(NewAPIKeyCheckHandler())
	chain.Add(&LatencyTrackerHandler{})

	fmt.Println("Go APIHandler extension blueprint on :8090")
	fmt.Println("Test: curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get")
	fmt.Println("Test 401: curl http://localhost:8090/get")
	http.ListenAndServe(":8090", chain)
}
