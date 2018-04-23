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
  if f.id > 0 {
    f.restaurant = fetchRestaurant(f.id)
  } else {
    f.restaurant = new(Restaurant)
  }
}

func (f *EditRestaurantForm) Layout() *EditFormLayout {
  layout := NewEditFormLayout("Restaurant")

  layout.AddRow(EditFormGroup("",
        EditFormString("Slug", "Slug", f.restaurant.Slug),
        EditFormString("Name", "Name", f.restaurant.Name)))
  layout.AddRow(EditFormGroup("",
        EditFormString("Address1", "Address", f.restaurant.Address1),
        EditFormString("Address2", "", f.restaurant.Address2),
        EditFormString("Town", "Town/City", f.restaurant.Town)))
  layout.AddRow(EditFormGroup("",
        EditFormString("Phone", "Phone", f.restaurant.Phone)))
  layout.AddRow(EditFormGroup("",
        EditFormString("MapLocation", "Map Location", f.restaurant.MapLocation),
        EditFormString("MapZoom", "Map Zoom", f.restaurant.MapZoom)))
  layout.AddRow(EditFormGroup("",
        EditFormText("About", "About", f.restaurant.About)))

  return layout
}

func (r *EditRestaurantForm) Validate(submission map[string]string) EditFormErrors {

  //f.restaurant.Slug = EditFormRequiredString(submission

  return EditFormErrors{}
}
func (r *EditRestaurantForm) Save() {}






