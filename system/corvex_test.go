package system

import (
	"encoding/json"
	"testing"
)

// The agent adds daemon, agent_version and features to GET /api/system. Every upstream field
// must keep its name and value, and features must be a JSON array, never null.
func TestAgentFieldsAreAdditive(t *testing.T) {
	AgentVersion = "1.13.4-cvx.1"
	t.Cleanup(func() { AgentVersion = "develop" })

	upstream := &Information{Version: "1.13.4"}
	upstream.System.Architecture = "amd64"
	before, err := json.Marshal(upstream)
	if err != nil {
		t.Fatal(err)
	}
	after, err := json.Marshal(struct {
		*Information
		AgentInformation
	}{upstream, CurrentAgentInformation()})
	if err != nil {
		t.Fatal(err)
	}

	var a, b map[string]any
	_ = json.Unmarshal(before, &a)
	_ = json.Unmarshal(after, &b)
	for k, v := range a {
		got, _ := json.Marshal(b[k])
		want, _ := json.Marshal(v)
		if string(got) != string(want) {
			t.Errorf("field %q changed: %s -> %s", k, want, got)
		}
	}
	if _, ok := b["layout"]; !ok {
		t.Errorf("layout missing: %s", after)
	}
	if b["daemon"] != "corvex-agent" || b["agent_version"] != "1.13.4-cvx.1" {
		t.Errorf("agent fields missing: %s", after)
	}
	if f, ok := b["features"].([]any); !ok || len(f) != 0 {
		t.Errorf("features must be an empty array: %s", after)
	}
}
