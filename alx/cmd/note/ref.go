package note

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

var Name string

var RefCmd = &cobra.Command{
	Use:   "ref [OPTIONS]",
	Short: "Create a new reflection note",
	Run: func(cmd *cobra.Command, args []string) {
		if Name == "" {
			fmt.Println("The name of the reflection is required")
			os.Exit(1)
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

		tmpl := template.New("reflection")
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

		filePath := fmt.Sprintf("%s/%s/%s.md", brainDir, "2-self/20-reflections", Name)
		absoluteFilePath := fmt.Sprintf("%s/%s.md", "2-self/20-reflections", Name)

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
	RefCmd.Flags().StringVarP(&Name, "name", "n", "", "(required) Name of the reflection, i.e: 'this-is-a-reflection'")
}
