package main

import (
	"bufio"
	"io/fs"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

// The binary embeds the top-level notices and every license file the notices list.
func TestLegalFilesAreEmbedded(t *testing.T) {
	for _, p := range []string{"LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.md", "third_party/licenses/go/LICENSE"} {
		b, err := fs.ReadFile(legalFiles, p)
		require.NoError(t, err, p)
		require.NotEmpty(t, b, p)
	}

	license, err := fs.ReadFile(legalFiles, "LICENSE")
	require.NoError(t, err)
	require.Contains(t, string(license), "Dane Everitt")
	require.Contains(t, string(license), "Permission is hereby granted")

	notices, err := os.Open("THIRD_PARTY_NOTICES.md")
	require.NoError(t, err)
	defer notices.Close()
	listed := 0
	scanner := bufio.NewScanner(notices)
	for scanner.Scan() {
		for _, part := range strings.Split(scanner.Text(), "`") {
			if strings.HasPrefix(part, "third_party/licenses/") {
				_, err := fs.Stat(legalFiles, strings.TrimSuffix(part, "/"))
				require.NoError(t, err, part)
				listed++
			}
		}
	}
	require.NoError(t, scanner.Err())
	require.Greater(t, listed, 100)
}
