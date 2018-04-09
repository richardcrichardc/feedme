package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "encoding/json"
  "strconv"
)


func handleRestaurant(w http.ResponseWriter, req *http.Request) {
  id := decodeId(req)

  var restaurant *Restaurant

  if id == 0 {
    restaurant = new(Restaurant)
  } else {
    restaurant = fetchRestaurant(id)
  }

  jsonBytes, _ := json.MarshalIndent(restaurant, "", "  ")

  w.Header().Set("Content-Type", "text/plain")
  w.Write(jsonBytes)
}


func decodeId(req *http.Request) int {
  val := mux.Vars(req)["id"]

  if val == "new" {
    return 0
  }

  id, err := strconv.Atoi(val)

  if err != nil {
    panic(BadRequest("Expecting 'new' or integer id, received: " + val))
  }

  return id
}
