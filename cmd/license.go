package cmd

// Corvex addition (see BRANDING.md): `corvex-agent license` prints the license texts embedded in the
// binary. It only reads those texts; no configuration, node state or protocol is involved.

import (
	"fmt"
	"io"
	"io/fs"

	"github.com/spf13/cobra"
)

// LegalFiles holds LICENSE, NOTICE, THIRD_PARTY_NOTICES.md and third_party/licenses. The main
// package sets it (corvex_legal.go); it stays nil in a build of wings.go alone.
var LegalFiles fs.FS

func init() {
	rootCommand.AddCommand(newLicenseCommand())
}

func newLicenseCommand() *cobra.Command {
	var all bool
	command := &cobra.Command{
		Use:   "license",
		Short: "Prints the license and the third-party notices and exits.",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return printLicenses(cmd.OutOrStdout(), LegalFiles, all)
		},
	}
	command.Flags().BoolVar(&all, "all", false, "also print THIRD_PARTY_NOTICES.md and the license of every Go module in this binary")
	return command
}

// printLicenses writes LICENSE and NOTICE and, with all, THIRD_PARTY_NOTICES.md and every file
// under third_party/licenses, each under a "==> path <==" header.
func printLicenses(w io.Writer, files fs.FS, all bool) error {
	if files == nil {
		_, err := fmt.Fprintln(w, "This build has no license texts embedded. Corvex Agent is based on Pterodactyl Wings (MIT):\n"+
			"see LICENSE, NOTICE and THIRD_PARTY_NOTICES.md in the source tree or the release archive.")
		return err
	}

	paths := []string{"LICENSE", "NOTICE"}
	if all {
		paths = append(paths, "THIRD_PARTY_NOTICES.md")
		err := fs.WalkDir(files, "third_party/licenses", func(p string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				paths = append(paths, p)
			}
			return err
		})
		if err != nil {
			return err
		}
	}

	for i, p := range paths {
		b, err := fs.ReadFile(files, p)
		if err != nil {
			return err
		}
		if i > 0 {
			fmt.Fprintln(w)
		}
		fmt.Fprintf(w, "==> %s <==\n%s", p, b)
		if len(b) > 0 && b[len(b)-1] != '\n' {
			fmt.Fprintln(w)
		}
	}
	if !all {
		fmt.Fprintln(w, "\nRun 'corvex-agent license --all' for the third-party notices and the license of every Go module in this binary.")
	}
	return nil
}
