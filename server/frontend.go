package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
)

func getFrontEnd(w http.ResponseWriter, req *http.Request) {
  slug := mux.Vars(req)["slug"]
  restaurant := fetchRestaurantBySlug(slug)

  templates.ElmApp(w, req, "PlaceOrder", restaurant)
}

func getRouter(w http.ResponseWriter, req *http.Request) {
  templates.ElmApp(w, req, "Router", "Nada")
}
