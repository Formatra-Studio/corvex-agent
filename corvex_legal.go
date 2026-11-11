package main

// Corvex addition (see BRANDING.md): embeds the license texts in the binary, so every copy of
// corvex-agent carries them, also the bare binary the node bootstrap installs. Printed by
// `corvex-agent license`; nothing else reads them.

import (
	"embed"

	"github.com/pterodactyl/wings/cmd"
)

//go:embed LICENSE NOTICE THIRD_PARTY_NOTICES.md third_party/licenses
var legalFiles embed.FS

func init() {
	cmd.LegalFiles = legalFiles
}
