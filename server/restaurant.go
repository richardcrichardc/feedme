package main

import (
  "net/http"
)

type Restaurant struct {
  Id int

  Slug string
  Name string

  Address1 string
  Address2 string
  Town string
  Phone string

  MapLocation string
  MapZoom string

  About string

  Menu rawJson
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


type EditRestaurantForm struct {
  id int
  restaurant *Restaurant
 }

func (f *EditRestaurantForm) Key(req *http.Request) {
  f.id = DecodeId(req)
}

func (f *EditRestaurantForm) Fetch() {
  f.restaurant = fetchRestaurant(f.id)
}

func (f *EditRestaurantForm) Layout() EditFormSpec {
  return EditFormSpec{
    What: "Restaurant",
    Rows: []EditFormRow{
      EditFormString("Slug", "Slug", f.restaurant.Slug),
      EditFormString("Name", "Name", f.restaurant.Name),
      EditFormString("Address1", "Address", f.restaurant.Address1),
      EditFormString("Address2", "", f.restaurant.Address2),
      EditFormString("Town", "Town/City", f.restaurant.Town),
      EditFormString("Phone", "Phone", f.restaurant.Phone),
      EditFormString("MapLocation", "MapLocation", f.restaurant.MapLocation),
      EditFormString("MapZoom", "MapZoom", f.restaurant.MapZoom),
      EditFormText("About", "About", f.restaurant.About),
  }}
}


func (r *EditRestaurantForm) Validate() EditFormErrors { return EditFormErrors{} }
func (r *EditRestaurantForm) Save() {}






