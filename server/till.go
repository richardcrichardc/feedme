package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "feedme/server/templates"
  "github.com/jinzhu/gorm"
)


func getTill(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {

  slug := mux.Vars(req)["slug"]
  restaurant := fetchRestaurantBySlug(tx, slug)
  orders := fetchTillOrders(tx, restaurant.ID)

  flags := struct {
    Restaurant *Restaurant
    Orders []TillOrder
  }{
    restaurant,
    orders,
  }

  templates.ElmApp(w, req, "BackEnd.Till", flags)
}
