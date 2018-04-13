package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "encoding/json"
  "html/template"
)

func getFrontEnd(w http.ResponseWriter, req *http.Request) {
  var flags struct {
    Fields struct {
      MenuId int `json:"menu_id"`
      Menu rawJson `json:"menu"`
    } `json:"fields"`
    Target struct {
      Method string `json:"method"`
      Url string `json:"url"`
      AuthToken string `json:"auth_token"`
    } `json:"target"`
  }

  slug := mux.Vars(req)["slug"]
  restaurant := fetchRestaurantBySlug(slug)
  flags.Fields.MenuId = 42
  flags.Fields.Menu = restaurant.Menu

  elmApp(w, req, "PlaceOrder", flags)
}

func elmApp(w http.ResponseWriter, req *http.Request, appName string, flags interface{}) {
  var d struct {
    App template.JS
    Flags template.JS
  }

  flagsJson, err := json.MarshalIndent(flags, "", "  ")
  checkError(err)

  d.App = template.JS(appName)
  d.Flags = template.JS(string(flagsJson))

  templates.Lookup("elm-spa.tmpl").Execute(w, d)
}
