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

		brainDir, err := utils.GetEnv("BRAIN")
		if err != nil {
			println("The BRAIN environment variable is not set")
			println(err.Error())
			os.Exit(1)
		}

		editor, err := utils.GetEnv("EDITOR")
		if err != nil {
			println(err.Error())
			os.Exit(1)
		}

		if exists, err := utils.CommandExists(editor); !exists {
			fmt.Printf("The %s command does not exist ", editor)
			println(err.Error())
			os.Exit(1)
		}

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
		tmpl, err = tmpl.Parse(templateStr)
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

		filePath := fmt.Sprintf("%s/%s/%s.md", brainDir, "2-self", Name)
		absoluteFilePath := fmt.Sprintf("%s/%s.md", "2-self", Name)

		if _, err := utils.CreateFile(filePath, contentBuffer); err != nil {
			// If the file already exists, let's continue with the execution
			if err != err.(*utils.FileExistsError) {
				fmt.Println(err.Error())
				os.Exit(1)
			}
		}

		if withinEditor := utils.FileCreatedFromEditor(); !withinEditor {
			cmd := exec.Command(editor, "-c", "cd "+brainDir, "-c", "e "+absoluteFilePath, "-c", "normal 3j")
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Run()
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
}
