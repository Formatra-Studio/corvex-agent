package config

// Corvex Agent: default locations. See BRANDING.md.
//
// New installs keep everything under /etc/corvex-agent, /var/lib/corvex-agent and
// /var/log/corvex-agent and use the corvex_nw Docker network. A node that moved over from
// Pterodactyl Wings keeps its config.yml at /etc/pterodactyl/config.yml; when the agent reads
// that file, every default stays the upstream one, so a key missing from the file never moves
// data, logs or the Docker network somewhere new.

import "os"

// LegacyLocation is where Pterodactyl Wings keeps its configuration file.
const LegacyLocation = "/etc/pterodactyl/config.yml"

// DefaultConfigLocation picks the configuration file to read when no --config flag was given:
// the agent's own file, or the Wings file when only that one exists.
func DefaultConfigLocation() string {
	if _, err := os.Stat(DefaultLocation); err != nil && os.IsNotExist(err) {
		if _, err := os.Stat(LegacyLocation); err == nil {
			return LegacyLocation
		}
	}
	return DefaultLocation
}

// UsesLegacyDefaults reports whether this configuration was read from the Wings location.
func (c *Configuration) UsesLegacyDefaults() bool {
	return c.path == LegacyLocation
}

// applyLegacyDefaults puts back the upstream defaults for every value the agent changed.
// Values present in the file are applied afterwards and still win.
func applyLegacyDefaults(c *Configuration) {
	c.System.RootDirectory = "/var/lib/pterodactyl"
	c.System.LogDirectory = "/var/log/pterodactyl"
	c.System.Data = "/var/lib/pterodactyl/volumes"
	c.System.ArchiveDirectory = "/var/lib/pterodactyl/archives"
	c.System.BackupDirectory = "/var/lib/pterodactyl/backups"
	c.System.TmpDirectory = "/tmp/pterodactyl"
	c.Docker.Network.Name = "pterodactyl_nw"
	c.Docker.Network.Mode = "pterodactyl_nw"
}

// DockerBridgeName is the host interface name used when the agent creates its Docker network.
func DockerBridgeName(network string) string {
	if network == "pterodactyl_nw" {
		return "pterodactyl0"
	}
	return "corvex0"
}

// LogFileName is the daemon's log file inside the log directory.
const LogFileName = "corvex-agent.log"
