package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/lambda"
)

// MCPToolRequest is the shape AgentCore Gateway sends to a Lambda tool.
// Verify exact field names in Gateway docs during Day 1 primer.
type MCPToolRequest struct {
	ToolName   string          `json:"toolName"`
	Parameters json.RawMessage `json:"parameters"`
}

type MCPToolResponse struct {
	Content []ContentBlock `json:"content"`
}

type ContentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type GetEmployeeParams struct {
	EmployeeID string `json:"employeeId"`
}

type GetDepartmentParams struct {
	Department string `json:"department"`
}

func handler(ctx context.Context, req MCPToolRequest) (MCPToolResponse, error) {
	switch req.ToolName {
	case "getEmployee":
		var p GetEmployeeParams
		if err := json.Unmarshal(req.Parameters, &p); err != nil {
			return errorResponse(fmt.Sprintf("invalid params: %v", err)), nil
		}
		employee := map[string]string{
			"E001": `{"id":"E001","name":"Alice Smith","department":"Engineering","title":"Staff Engineer","email":"alice@example.com"}`,
			"E002": `{"id":"E002","name":"Bob Jones","department":"Finance","title":"Analyst","email":"bob@example.com"}`,
		}
		if rec, ok := employee[p.EmployeeID]; ok {
			return textResponse(rec), nil
		}
		return textResponse(fmt.Sprintf(`{"error":"employee %s not found"}`, p.EmployeeID)), nil

	case "listDepartment":
		var p GetDepartmentParams
		if err := json.Unmarshal(req.Parameters, &p); err != nil {
			return errorResponse(fmt.Sprintf("invalid params: %v", err)), nil
		}
		return textResponse(fmt.Sprintf(`{"department":"%s","headcount":12,"manager":"Carol White"}`, p.Department)), nil

	default:
		return errorResponse(fmt.Sprintf("unknown tool: %s", req.ToolName)), nil
	}
}

func textResponse(text string) MCPToolResponse {
	return MCPToolResponse{Content: []ContentBlock{{Type: "text", Text: text}}}
}

func errorResponse(msg string) MCPToolResponse {
	return MCPToolResponse{Content: []ContentBlock{{Type: "text", Text: `{"error":"` + msg + `"}`}}}
}

func main() {
	lambda.Start(handler)
}
