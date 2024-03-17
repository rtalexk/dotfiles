package note

import (
	"alx/utils"

	"github.com/spf13/cobra"
)

var QuoteCmd = &cobra.Command{
	Use:   "quote",
	Short: "Open quotes",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir := utils.GetDirOrExit("BRAIN")
		editor := utils.GetEditorOrExit()

		// Open the editor in the BRAIN dir, open the quotes file and copy the template
		utils.ExecCmdOrExit(
			editor,
			"-c",
			"cd "+brainDir,
			"-c",
			"e 2-self/20-reflections/quotes.md",
			"-c",
			"normal 3gg^V6jyP7jww",
		)
	},
}

func init() {}
