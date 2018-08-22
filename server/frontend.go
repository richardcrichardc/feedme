package main

import (
  "net/http"
  "feedme/server/templates"
  "fmt"
  "io/ioutil"
  "encoding/json"
  "github.com/jinzhu/gorm"
  "log"
  "feedme/server/sse"
  "time"
)

func getFrontEnd(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  menu := fetchMenuForRestaurantID(tx, restaurant.ID)

  if menu == nil {
    menu = &Menu{Items: []MenuItem{}}
  }

  flags := struct {
    Restaurant *Restaurant
    MenuID uint
    Menu MenuItems
    GoogleStaticMapsKey string
  }{
    restaurant,
    menu.ID,
    menu.Items,
    Config.GoogleStaticMapsKey,
  }

  templates.ElmApp(w, req, "FrontEnd.Main", flags)
}


func getFrontEndStatus(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  order := fetchLatestOrder(tx, restaurant.ID, sessionID)

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

func postPlaceOrder(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  var order OrderWithSessionID

  body, _ := ioutil.ReadAll(req.Body)
  checkError(json.Unmarshal(body, &order))
  fmt.Printf("Order: %#v", order)
  order.Menu = fetchMenu(tx, order.MenuID)
  order.RestaurantID = order.Menu.RestaurantID
  order.SessionID = sessionID
  order.Status = "New"
  order.CreatedAt = time.Now()
  order.StatusDate = &order.CreatedAt

  order.Recalc()

  query := "UPDATE restaurant_order_numbers SET last_order_number=last_order_number+1 WHERE restaurant_id=$1 RETURNING last_order_number"
  checkError(tx.CommonDB().QueryRow(query, order.RestaurantID).Scan(&order.Number))

  checkError(tx.Table("orders").Create(&order).Error)


  log.Printf("PlaceOrder:\n%s\n%#v\n", body, order)

  sse.Send(restaurantStreamId(order.RestaurantID), &sse.Event{"order", &TillOrder{
    Number: order.Number,
    Name: order.Name,
    Telephone: order.Telephone,
    MenuID: order.MenuID,
    MenuItems: order.Menu.Items,
    Items: order.Items,
    Status: order.Status,
    StatusDate: order.StatusDate,
    CreatedAt: order.CreatedAt,
  }})

  json.NewEncoder(w).Encode(OrderResult{Status: "OK"})
}



