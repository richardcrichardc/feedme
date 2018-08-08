package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
  "fmt"
  "io/ioutil"
  "encoding/json"
  "github.com/jinzhu/gorm"
)

func getFrontEnd(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
  slug := mux.Vars(req)["slug"]
  menu := fetchMenuForRestaurantSlug(tx, slug)

  flags := struct {
    Restaurant *Restaurant
    MenuID uint
    Menu MenuItems
    GoogleStaticMapsKey string
  }{
    menu.Restaurant,
    menu.ID,
    menu.Items,
    Config.GoogleStaticMapsKey,
  }

  templates.ElmApp(w, req, "FrontEnd.Main", flags)
}


func getFrontEndStatus(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {

  slug := mux.Vars(req)["slug"]
  order := fetchLatestOrder(tx, slug, sessionID)

  if order == nil {

  }

  flags := struct {
    Restaurant *Restaurant
    Menu MenuItems
    Order OrderItems
  }{
    order.Menu.Restaurant,
    order.Menu.Items,
    order.Items,
  }

  templates.ElmApp(w, req, "FrontEnd.Status", flags)
}


type OrderResult struct {
  Status string
  Error string
}

func postPlaceOrder(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
  var order OrderWithSessionID

  body, _ := ioutil.ReadAll(req.Body)
  checkError(json.Unmarshal(body, &order))
  fmt.Printf("Order: %#v", order)
  order.Menu = fetchMenu(tx, order.MenuID)
  order.RestaurantID = order.Menu.RestaurantID
  order.SessionID = sessionID

  order.Recalc()

  query := "UPDATE restaurants SET last_order_number=last_order_number+1 WHERE id=$1 RETURNING last_order_number"
  checkError(tx.CommonDB().QueryRow(query, order.RestaurantID).Scan(&order.Number))

  checkError(tx.Table("orders").Create(&order).Error)


  fmt.Printf("PlaceOrder:\n%s\n%#v\n", body, order)


  json.NewEncoder(w).Encode(OrderResult{Status: "OK"})
}



