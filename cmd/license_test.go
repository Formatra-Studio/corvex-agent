package cmd

import (
	"bytes"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/require"
)

var testLegalFiles = fstest.MapFS{
	"LICENSE":                         {Data: []byte("MIT License\n")},
	"NOTICE":                          {Data: []byte("Corvex Agent")},
	"THIRD_PARTY_NOTICES.md":          {Data: []byte("# Third-party notices\n")},
	"third_party/licenses/go/LICENSE": {Data: []byte("Go license\n")},
	"third_party/licenses/example.com/a/LICENSE": {Data: []byte("A license\n")},
	"third_party/licenses/example.com/a/NOTICE":  {Data: []byte("A notice\n")},
}

func TestLicensePrintsLicenseAndNotice(t *testing.T) {
	var out bytes.Buffer
	require.NoError(t, printLicenses(&out, testLegalFiles, false))

	require.Equal(t, "==> LICENSE <==\nMIT License\n\n==> NOTICE <==\nCorvex Agent\n\n"+
		"Run 'corvex-agent license --all' for the third-party notices and the license of every Go module in this binary.\n", out.String())
}

func TestLicenseAllPrintsEveryThirdPartyFile(t *testing.T) {
	var out bytes.Buffer
	require.NoError(t, printLicenses(&out, testLegalFiles, true))

	require.Equal(t, "==> LICENSE <==\nMIT License\n\n==> NOTICE <==\nCorvex Agent\n\n"+
		"==> THIRD_PARTY_NOTICES.md <==\n# Third-party notices\n\n"+
		"==> third_party/licenses/example.com/a/LICENSE <==\nA license\n\n"+
		"==> third_party/licenses/example.com/a/NOTICE <==\nA notice\n\n"+
		"==> third_party/licenses/go/LICENSE <==\nGo license\n", out.String())
}

func TestLicenseWithoutEmbeddedFiles(t *testing.T) {
	var out bytes.Buffer
	require.NoError(t, printLicenses(&out, nil, true))
	require.Contains(t, out.String(), "Pterodactyl Wings (MIT)")
}

func TestLicenseCommandIsRegistered(t *testing.T) {
	command, _, err := rootCommand.Find([]string{"license"})
	require.NoError(t, err)
	require.Equal(t, "license", command.Name())
	require.NotNil(t, command.Flags().Lookup("all"))
}
