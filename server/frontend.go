package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
  "fmt"
  "io/ioutil"
  "encoding/json"
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
  var order Order

  body, _ := ioutil.ReadAll(req.Body)
  checkError(json.Unmarshal(body, &order))
  menu := fetchMenu(order.MenuId)
  //restaurant := fetchRestaurant(menu.RestaurantId)

  order.Recalc(menu)
  order.Create(req.Context())

  fmt.Printf("PlaceOrder:\n%s\n%#v\n%#v\n", body, order, menu)

  fmt.Fprintf(w, `"OK"`)
}



func getRouter(w http.ResponseWriter, req *http.Request) {
  templates.ElmApp(w, req, "Router", "Nada")
}
