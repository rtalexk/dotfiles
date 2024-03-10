package work

import (
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

var (
	Name string
	Once bool
)

var NoteCmd = &cobra.Command{
	Use:   "note [OPTIONS]",
	Short: "Create a new work note",
	Long: `The note will be created in the 1-work directory.

The difference between normal and 'once' notes is that 'once' are used for one-off
tasks, such as a one-time meeting, an incident; they are placed under the once
directory and the timestamp of the note is used as prefix for the filename, whereas
the normal notes are used for recurring tasks, how-tos, guides, documentation, etc.`,
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

		filePath := ""
		absoluteFilePath := ""

		if Once {
			filePath = fmt.Sprintf("%s/%s/%s-%s.md", brainDir, "1-work/nuvo/once", date, Name)
			absoluteFilePath = fmt.Sprintf("%s/%s-%s.md", "1-work/nuvo/once", date, Name)
		} else {
			filePath = fmt.Sprintf("%s/%s/%s.md", brainDir, "1-work/nuvo", Name)
			absoluteFilePath = fmt.Sprintf("%s/%s.md", "1-work/nuvo", Name)
		}

		if _, err := utils.CreateFile(filePath, contentBuffer); err != nil {
			// If the file already exists, let's continue with the execution
			fmt.Println(err.Error())
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
	NoteCmd.Flags().StringVarP(&Name, "name", "n", "", "(required) Name of the reflection, i.e: 'this-is-a-reflection'")
	NoteCmd.Flags().BoolVarP(&Once, "once", "o", false, "[optional] One-off note")
}
