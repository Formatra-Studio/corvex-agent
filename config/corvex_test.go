package config

import (
	"os"
	"path/filepath"
	"testing"

	"gopkg.in/yaml.v2"
)

func loadAt(t *testing.T, path string, body string) *Configuration {
	t.Helper()
	c, err := NewAtPath(path)
	if err != nil {
		t.Fatal(err)
	}
	if body != "" {
		f := filepath.Join(t.TempDir(), "config.yml")
		if err := os.WriteFile(f, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		if err := yaml.Unmarshal(b, c); err != nil {
			t.Fatal(err)
		}
	}
	return c
}

func TestNewInstallsUseAgentDefaults(t *testing.T) {
	c := loadAt(t, DefaultLocation, "")
	if c.UsesLegacyDefaults() {
		t.Fatal("the agent location must not use legacy defaults")
	}
	checks := [][2]string{
		{c.System.RootDirectory, "/var/lib/corvex-agent"},
		{c.System.LogDirectory, "/var/log/corvex-agent"},
		{c.System.Data, "/var/lib/corvex-agent/volumes"},
		{c.System.ArchiveDirectory, "/var/lib/corvex-agent/archives"},
		{c.System.BackupDirectory, "/var/lib/corvex-agent/backups"},
		{c.System.TmpDirectory, "/tmp/corvex-agent"},
		{c.Docker.Network.Name, "corvex_nw"},
		{c.Docker.Network.Mode, "corvex_nw"},
		{c.LayoutName(), "corvex"},
		{c.System.Username, "corvex"},
		{c.System.Passwd.Directory, "/run/corvex-agent/etc"},
		{c.System.MachineID.Directory, "/run/corvex-agent/machine-id"},
		{c.DatabaseFileName(), "corvex-agent.db"},
	}
	for _, pair := range checks {
		if pair[0] != pair[1] {
			t.Errorf("got %q, want %q", pair[0], pair[1])
		}
	}
	if DockerBridgeName(c.Docker.Network.Name) != "corvex0" {
		t.Error("new installs create the corvex0 bridge")
	}
}

func TestMigratedNodesKeepWingsDefaults(t *testing.T) {
	c := loadAt(t, LegacyLocation, "")
	if !c.UsesLegacyDefaults() {
		t.Fatal("the Wings location must use legacy defaults")
	}
	checks := [][2]string{
		{c.System.RootDirectory, "/var/lib/pterodactyl"},
		{c.System.LogDirectory, "/var/log/pterodactyl"},
		{c.System.Data, "/var/lib/pterodactyl/volumes"},
		{c.System.ArchiveDirectory, "/var/lib/pterodactyl/archives"},
		{c.System.BackupDirectory, "/var/lib/pterodactyl/backups"},
		{c.System.TmpDirectory, "/tmp/pterodactyl"},
		{c.Docker.Network.Name, "pterodactyl_nw"},
		{c.Docker.Network.Mode, "pterodactyl_nw"},
		{DockerBridgeName(c.Docker.Network.Name), "pterodactyl0"},
		{c.LayoutName(), "pterodactyl"},
		{c.System.Username, "pterodactyl"},
		{c.System.Passwd.Directory, "/run/wings/etc"},
		{c.System.MachineID.Directory, "/run/wings/machine-id"},
		{c.DatabaseFileName(), "wings.db"},
	}
	for _, pair := range checks {
		if pair[0] != pair[1] {
			t.Errorf("got %q, want %q", pair[0], pair[1])
		}
	}
}

func TestValuesInTheFileStillWin(t *testing.T) {
	c := loadAt(t, LegacyLocation, "system:\n  data: /srv/volumes\ndocker:\n  network:\n    name: custom_nw\n")
	if c.System.Data != "/srv/volumes" {
		t.Errorf("data = %q", c.System.Data)
	}
	if c.Docker.Network.Name != "custom_nw" {
		t.Errorf("network = %q", c.Docker.Network.Name)
	}
	if c.System.RootDirectory != "/var/lib/pterodactyl" {
		t.Errorf("root = %q", c.System.RootDirectory)
	}
}

func TestLegacyLocationIsMatchedAfterCleaning(t *testing.T) {
	c := loadAt(t, "/etc/pterodactyl//config.yml", "")
	if !c.UsesLegacyDefaults() || c.System.RootDirectory != "/var/lib/pterodactyl" {
		t.Fatalf("a non-canonical spelling of the Wings path must keep the Wings defaults, root = %q", c.System.RootDirectory)
	}
}
