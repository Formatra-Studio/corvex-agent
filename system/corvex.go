package system

// Corvex Agent identity. See BRANDING.md.

// Daemon names this daemon in GET /api/system, so a panel can tell it apart from upstream Wings.
const Daemon = "corvex-agent"

// AgentVersion is the agent release, "<upstream version>-cvx.<n>"; set with -ldflags at build
// time. Version (const.go) stays the upstream Wings version the agent is based on, because
// panels compare it against the Wings versions they support.
var AgentVersion = "develop"

// Features lists agent-only abilities a panel may use. Empty while the agent only rebrands Wings.
var Features = []string{}

// AgentInformation is added to both GET /api/system responses. The fields are additive: every
// upstream field keeps its name, type and value.
type AgentInformation struct {
	Daemon       string   `json:"daemon"`
	AgentVersion string   `json:"agent_version"`
	Features     []string `json:"features"`
	// Layout is "pterodactyl" or "corvex" (see config.LayoutName); filled in by the router.
	Layout string `json:"layout"`
}

// CurrentAgentInformation describes this build.
func CurrentAgentInformation() AgentInformation {
	features := make([]string, len(Features))
	copy(features, Features)
	return AgentInformation{Daemon: Daemon, AgentVersion: AgentVersion, Features: features}
}
