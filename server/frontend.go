package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
  "fmt"
  "io/ioutil"
)

type FrontEndFlags struct {
    *RestaurantAndMenu
    GoogleStaticMapsKey string
}

func getFrontEnd(w http.ResponseWriter, req *http.Request) {
  var flags FrontEndFlags

  slug := mux.Vars(req)["slug"]
  flags.RestaurantAndMenu = fetchRestaurantAndMenuBySlug(slug)
  flags.GoogleStaticMapsKey = Config.GoogleStaticMapsKey

  templates.ElmApp(w, req, "FrontEnd", flags)
}

func postPlaceOrder(w http.ResponseWriter, req *http.Request) {
  body, _ := ioutil.ReadAll(req.Body)
  fmt.Printf("PlaceOrder: %s\n", body)
  fmt.Fprintf(w, `"OK"`)
}



func getRouter(w http.ResponseWriter, req *http.Request) {
  templates.ElmApp(w, req, "Router", "Nada")
}
