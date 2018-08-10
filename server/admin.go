package main

import (
  "net/http"
  "feedme/server/templates"
  "github.com/jinzhu/gorm"
  ef "feedme/server/editform"
  "encoding/json"
  "fmt"
  "io/ioutil"
)


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

func editMenu(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
  restaurantID := ef.GetId(req)

  switch req.Method {
  case "GET":
    var items MenuItems
    menu := fetchMenuForRestaurantID(tx, restaurantID)

    if menu == nil {
      items = MenuItems{
        MenuItem{
          Id: 1,
          Name: "name",
          Desc: "desc",
          Price: 4242,
        },
      }
    } else {
      items = menu.Items
    }

    menuJson, err := json.MarshalIndent(items, "", "  ")
    checkError(err)

    data := struct {
        Url string
        CancelUrl string
        SavedUrl string
        Json string
    }{
        fmt.Sprintf("/admin/restaurants/%d/menu", restaurantID),
        "/admin/restaurants",
        "/admin/restaurants",
        string(menuJson),
    }

    templates.ElmApp(w, req, "MenuEditor", data)

  case "POST":
    menu := Menu{RestaurantID: restaurantID}

    body, err := ioutil.ReadAll(req.Body)
    checkError(err)

    checkError(json.Unmarshal(body, &menu.Items))

    checkError(tx.Create(&menu).Error)

    fmt.Fprint(w, "\"OK\"")
  }
}

