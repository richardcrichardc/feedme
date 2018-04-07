package main

import (
  "html/template"
)

var templates *template.Template

func initTemplates() {
  templates = template.New("root")

  templates.Funcs(template.FuncMap{
    "asset": assetPath,
  })

  _, err := templates.ParseGlob("templates/*.tmpl")
  checkError(err)

}

