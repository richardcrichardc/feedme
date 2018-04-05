package main

import (
  "html/template"
)

var templates *template.Template

func initTemplates() {
  templates = template.Must(template.ParseGlob("templates/*.tmpl"))

  //for _, t := range templates.Templates() {
  //  fmt.Printf("template: %s", t.Name())
  //}
}

