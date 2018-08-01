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
  Restaurant
  MenuID uint
  Menu MenuItems
  GoogleStaticMapsKey string
}

func getFrontEnd(w http.ResponseWriter, req *http.Request) {
  var flags FrontEndFlags

  slug := mux.Vars(req)["slug"]
  menu := fetchMenuForRestaurantSlug(slug)

  flags.Restaurant = menu.Restaurant
  flags.MenuID = menu.ID
  flags.Menu = menu.Items
  flags.GoogleStaticMapsKey = Config.GoogleStaticMapsKey

  templates.ElmApp(w, req, "FrontEnd", flags)
}

func postPlaceOrder(w http.ResponseWriter, req *http.Request) {
  var order Order

  body, _ := ioutil.ReadAll(req.Body)
  checkError(json.Unmarshal(body, &order))
  fmt.Printf("Order: %#v", order)
  order.Menu = *fetchMenu(order.MenuID)
  order.RestaurantID = order.Menu.RestaurantID

  order.Recalc()

  query := "UPDATE restaurants SET last_order_number=last_order_number+1 WHERE id=$1 RETURNING last_order_number"

  checkError(db.CommonDB().QueryRow(query, order.RestaurantID).Scan(&order.Number))

  checkError(db.Create(&order).Error)


  fmt.Printf("PlaceOrder:\n%s\n%#v\n", body, order)

  fmt.Fprintf(w, `"OK"`)
}



