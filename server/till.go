package main

import (
  "net/http"
  "feedme/server/templates"
  "feedme/server/sse"
  "github.com/jinzhu/gorm"
  "encoding/json"
  "time"
  "strings"
  "strconv"
  "fmt"
)

func getTill(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  flags := struct {
    Restaurant *Restaurant
  }{
    restaurant,
  }

  templates.ElmApp(w, req, "BackEnd.Till", flags)
}

func getTillStream(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  var events [] sse.Event
  events = append(events, sse.Event{"reset", nil})

  for _, order := range fetchTillOrders(tx, restaurant.ID) {
    events = append(events, sse.Event{"order", order})
  }

  sse.Stream(w, events, restaurantStreamKey(restaurant.ID))
}

func postUpdateOrder(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  update := struct {
    Number int
    Status string
  }{}
  checkError(json.NewDecoder(req.Body).Decode(&update))

  var order Order
  checkError(tx.Where("restaurant_id = ? AND Number = ?", restaurant.ID, update.Number).First(&order).Error)

  statusFields := strings.Fields(update.Status)
  order.Status = statusFields[0]

  if len(statusFields) > 1 {
    unixMillis, err := strconv.ParseInt(statusFields[1], 10, 64)
    checkError(err)
    statusDate := time.Unix(unixMillis / 1000, unixMillis % 1000)
    order.StatusDate = &statusDate
  } else {
    order.StatusDate = nil
  }

  checkError(tx.Save(order).Error)

  // send status updates to customers and other tills
  event := &sse.Event{
    "statusUpdate",
    &OrderStatusUpdate{
      RestaurantID: order.RestaurantID,
      Number: order.Number,
      Status: order.Status,
      StatusDate: order.StatusDate,
  }}
  sse.Send(restaurantOrderStreamKey{order.RestaurantID, order.Number}, event)
  sse.Send(restaurantStreamKey(order.RestaurantID), event)


  w.Header().Set("Content-Type", "application/json")
  fmt.Fprintln(w, "\"OK\"")
}
