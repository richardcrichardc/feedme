package main

import (
  "net/http"
  "feedme/server/templates"
  "feedme/server/sse"
  "github.com/jinzhu/gorm"
  "sync"
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
