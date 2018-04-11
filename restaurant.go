package main

import (
  "github.com/gorilla/mux"
  "net/http"
  //"encoding/json"
  "strconv"
)

type Restaurant struct {
  Id uint

  Slug string
  Name string

  Address1 string
  Address2 string
  Town string
  Phone string

  MapLocation string
  MapZoom string

  About string

  Menu string
}

func fetchRestaurant(id int) *Restaurant {
  var restaurant Restaurant
  checkError(db.Get(&restaurant, "SELECT * FROM restaurants WHERE id = $1", id))
  return &restaurant
}

func fetchRestaurantBySlug(slug string) *Restaurant {
  var restaurant Restaurant
  checkError(db.Get(&restaurant, "SELECT * FROM restaurants WHERE slug = $1", slug))
  return &restaurant
}

func editRestaurant(w http.ResponseWriter, req *http.Request) {
  var restaurant *Restaurant

  id := decodeId(req)
  if id == 0 {
    restaurant = new(Restaurant)
  } else {
    restaurant = fetchRestaurant(id)
  }

  var form = EditForm{
    What: "Restaurant",
    Rows: []EditRow{
      {"Id", "Slug", "string", nil},
      {"Name", "Name", "string", nil},
      {"Address1", "Address", "string", nil},
      {"Address2", "", "string", nil},
      {"Town", "Town/City", "string", nil},
      {"Phone", "Phone", "string", nil},
      {"MapLocation", "Map Location", "string", nil},
      {"MapZoom", "Map Zoom", "string", nil},
      {"About", "About", "text", nil},
      {"Menu", "Menu", "text", nil},
    },
    Data: restaurant,
  }


  /*
  jsonBytes, _ := json.MarshalIndent(form, "", "  ")

  w.Header().Set("Content-Type", "text/plain")
  w.Write(jsonBytes)
  */

  elmApp(w, req, "EditForm", form)
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
