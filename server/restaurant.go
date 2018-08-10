package main

import (
  "net/http"
  "feedme/server/templates"
  ef "feedme/server/editform"
  "time"
  "github.com/jinzhu/gorm"
)


type Restaurant struct {
  ID uint

  Slug string
  Name string

  Address1 string
  Address2 string
  Town string
  Phone string

  MapLocation string
  MapZoom string

  About string

  CreatedAt time.Time
  UpdatedAt time.Time
}

func (r *Restaurant) AfterCreate(tx *gorm.DB) (err error) {
  return tx.Create(&RestaurantOrderNumber{r.ID, 0}).Error
}

type RestaurantOrderNumber struct {
  RestaurantID uint `gorm:"primary_key"`
  LastOrderNumber uint
}

func fetchRestaurantBySlug(tx *gorm.DB, slug string) *Restaurant {
  var restaurant Restaurant
  checkError(tx.Where("slug=?", slug).Find(&restaurant).Error)
  return &restaurant
}



// List Restaurants


func getRestaurants(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
  var summaries []struct {
    ID int
    Slug string
    Name string
    URL string
  }
  checkError(tx.Table("restaurants").Find(&summaries).Error)

  for i := range summaries {
    summaries[i].URL = "http://" + summaries[i].Slug + "." + Config.DomainName + port(req) + "/"
  }

  templates.ElmApp(w, req, "Restaurants", summaries)
}

// Add/Edit Restaurant

type EditRestaurantForm struct {}


func NewEditRestaurantForm() ef.Form {
  return new(EditRestaurantForm)
}

func (f *EditRestaurantForm) New() interface{} {
  return new(Restaurant)
}

func (f *EditRestaurantForm) Layout(fi *ef.Instance) ef.Layout {
  return ef.NewLayout(
      "Restaurant",
      "/admin/restaurants",
      "/admin/restaurants",
      ef.Group("",
        ef.Text("Slug", "Slug"),
        ef.Text("Name", "Name")),
      ef.Group("",
        ef.Text("Address1", "Address"),
        ef.Text("Address2", ""),
        ef.Text("Town", "Town/City")),
      ef.Group("",
        ef.Text("Phone", "Phone")),
      ef.Group("",
        ef.Text("MapLocation", "Map Location"),
        ef.Text("MapZoom", "Map Zoom")),
      ef.Group("",
        ef.TextArea("About", "About")))
}

func (f *EditRestaurantForm) Validate(fi *ef.Instance) {
  fi.Validate("Slug", "Slug", ef.Trim, ef.Required)
  fi.Validate("Name", "Name", ef.Trim, ef.Required)
  fi.Validate("Address1", "Address", ef.Trim, ef.Required)
  fi.Validate("Address2", "Address", ef.Trim)
  fi.Validate("Town", "Town/City", ef.Trim, ef.Required)
  fi.Validate("Phone", "Phone", ef.Trim, ef.Required)
  fi.Validate("MapLocation", "Map Location", ef.Trim)
  fi.Validate("MapZoom", "Map Zoom", ef.Trim)
  fi.Validate("About", "About", ef.Trim)
}

