package cmd

import (
	"alx/cmd/note"
	"alx/utils"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"
	"time"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"

	"github.com/spf13/cobra"
)

var Name string
var Inbox bool

// noteCmd represents the note command
var noteCmd = &cobra.Command{
	Use:   "note [COMMAND] [OPTIONS]",
	Short: "Manage notes",
	Long: `If no subcommand is provided, it will create a new note.

  The name of the note will be used as the filename, added as metadata to the
  file and used as a default title.`,
	Run: func(cmd *cobra.Command, args []string) {
		if Name == "" {
			fmt.Println("The name of the note is required")
			os.Exit(1)
		}

		var noteDir string
		if Inbox {
			noteDir = utils.INBOX_DIR
		} else {
			noteDir = utils.SELF_DIR
		}

		brainDir := utils.GetDirOrExit("BRAIN")
		editor := utils.GetEditorOrExit()

		fileId := time.Now().Format("20060102150405")
		date := time.Now().Format("2006-01-02")
		title := cases.Title(language.Und).String(Name)
		title = strings.ReplaceAll(title, "-", " ")

		data := struct {
			Date   string
			Name   string
			Title  string
			FileId string
		}{
			Date:   date,
			Name:   Name,
			Title:  title,
			FileId: fileId,
		}

		templateStr := `---
Created At: {{ .Date }}
Filename: {{ .Name }}
Resource: 
---

# {{ .Title }}



Links:

{{ .FileId }}`

		tmpl := template.New("note")
		tmpl, err := tmpl.Parse(templateStr)
		if err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}

		var contentBuffer bytes.Buffer
		err = tmpl.Execute(&contentBuffer, data)
		if err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}

		filePath := fmt.Sprintf("%s/%s/%s.md", brainDir, noteDir, Name)
		absoluteFilePath := fmt.Sprintf("%s/%s.md", noteDir, Name)

		if _, err := utils.CreateFile(filePath, contentBuffer); err != nil {
			// If the file already exists, let's continue with the execution
			if err != err.(*utils.FileExistsError) {
				fmt.Println(err.Error())
				os.Exit(1)
			}
		}

		if withinEditor := utils.FileCreatedFromEditor(); !withinEditor {
			utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", "e "+absoluteFilePath, "-c", "normal 3j")
		} else {
			// Couldn't find a way to instruct the editor to open the file, so as a workaround
			// I'll just copy the file path to the clipboard and manually open the file
			cmd := exec.Command("pbcopy")
			cmd.Stdin = strings.NewReader(absoluteFilePath)
			cmd.Run()

			println(absoluteFilePath)
		}
	},
}

func init() {
	rootCmd.AddCommand(noteCmd)
	noteCmd.AddCommand(note.QuoteCmd)
	noteCmd.AddCommand(note.RefCmd)
	noteCmd.Flags().StringVarP(&Name, "name", "n", "", "(required) Name of the note, i.e: 'this-is-a-note'")
	noteCmd.Flags().BoolVarP(&Inbox, "inbox", "i", false, "[optional] Place note at Inbox")
}
