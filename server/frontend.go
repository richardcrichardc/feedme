package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
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

  templates.ElmApp(w, req, "PlaceOrder", flags)
}

