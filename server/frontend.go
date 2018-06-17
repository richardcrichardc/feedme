package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
)

type FrontEndFlags struct {
    *Restaurant
    GoogleStaticMapsKey string
}

func getFrontEnd(w http.ResponseWriter, req *http.Request) {
  var flags FrontEndFlags

  slug := mux.Vars(req)["slug"]
  flags.Restaurant = fetchRestaurantBySlug(slug)
  flags.GoogleStaticMapsKey = Config.GoogleStaticMapsKey

  templates.ElmApp(w, req, "PlaceOrder", flags)
}

func getRouter(w http.ResponseWriter, req *http.Request) {
  templates.ElmApp(w, req, "Router", "Nada")
}
