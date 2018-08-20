package main

import (
  "net/http"
  "feedme/server/templates"
  "feedme/server/sse"
  "github.com/jinzhu/gorm"
  "sync"
  "encoding/json"
  "time"
  "strings"
  "strconv"
  "fmt"
)

var tillStreams map[uint][]chan sse.Event
var tillStreamsLock sync.RWMutex

func init() {
  tillStreams = make(map[uint][]chan sse.Event)
}

// TODO review all this

func addTillStream(restaurantID uint, stream chan sse.Event) {
  tillStreamsLock.Lock()

  streams := tillStreams[restaurantID]
  if streams == nil {
    streams = make([]chan sse.Event, 0)
  }

  tillStreams[restaurantID] = append(streams, stream)

  tillStreamsLock.Unlock()
}

func removeTillStream(restaurantID uint, stream chan sse.Event) {
  tillStreamsLock.Lock()

  origStreams := tillStreams[restaurantID]
  if origStreams != nil {
    newStreams := make([]chan sse.Event, 0)

    for _, s := range origStreams {
      if s != stream {
        newStreams = append(newStreams, s)
      }
    }

    tillStreams[restaurantID] = newStreams
  }

  tillStreamsLock.Unlock()
}

func writeTillStreams(restaurantID uint, event sse.Event) {
  tillStreamsLock.RLock()
  streams := tillStreams[restaurantID]
  tillStreamsLock.RUnlock()

  if streams != nil {
    for _, stream := range streams {
      stream <- event
    }
  }
}

// END all this


func getTill(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  flags := struct {
    Restaurant *Restaurant
  }{
    restaurant,
  }

  templates.ElmApp(w, req, "BackEnd.Till", flags)
}

func getTillStream(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string, restaurant *Restaurant) {
  events := make(chan sse.Event, 64)
  events <- sse.Event{"reset", nil}
  addTillStream(restaurant.ID, events)

  go func() {
    for _, order := range fetchTillOrders(tx, restaurant.ID) {
      events <- sse.Event{"order", order}
    }
  }()

  sse.Stream(w, events)
  removeTillStream(restaurant.ID, events)
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

  w.Header().Set("Content-Type", "application/json")
  fmt.Fprintln(w, "\"OK\"")
}
