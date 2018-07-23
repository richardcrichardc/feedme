package main

import (
  "fmt"
  "io/ioutil"
  "net/http"
  "feedme/server/templates"
  ef "feedme/server/editform"
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
}

type RestaurantAndMenu struct {
  Restaurant
  MenuId int
  Menu rawJson
}


func fetchRestaurant(id int) *Restaurant {
  var restaurant Restaurant
  checkError(db.Get(&restaurant, "SELECT * FROM restaurants WHERE id = $1", id))
  return &restaurant
}


func fetchRestaurantAndMenu(id int) *RestaurantAndMenu {
  var restaurant RestaurantAndMenu
  query := fetchRestaurantAndMenuQuery("r.id")
  checkError(db.Get(&restaurant, query, id))
  return &restaurant
}


func fetchRestaurantAndMenuBySlug(slug string) *RestaurantAndMenu {
  var restaurant RestaurantAndMenu
  query := fetchRestaurantAndMenuQuery("slug")
  checkError(db.Get(&restaurant, query, slug))
  return &restaurant
}


func fetchRestaurantAndMenuQuery(key string) string {
  return `
    SELECT
      r.id,
      r.slug,
      r.name,
      r.address1,
      r.address2,
      r.town,
      r.phone,
      r.mapLocation,
      r.mapZoom,
      r.about,
      COALESCE(m.id, -1) as MenuId,
      COALESCE(m.items, '[]') as menu
    FROM restaurants r LEFT JOIN menus m ON r.id=m.restaurantId
    WHERE ` + key + ` = $1
    ORDER BY m.id desc
    LIMIT 1`
}

// List Restaurants

type RestaurantSummary struct {
  Id int
  Slug string
  Name string
}

func getRestaurants(w http.ResponseWriter, req *http.Request) {
  restaurants := make([]RestaurantSummary, 0)
  checkError(db.Select(&restaurants, "SELECT id, slug, name FROM restaurants ORDER BY name"))
  templates.ElmApp(w, req, "Restaurants", restaurants)
}

// Add/Edit Restaurant

type EditRestaurantForm struct {}

func EditRestaurantFormCols() []string {
  return []string{
    "Slug",
    "Name",
    "Address1",
    "Address2",
    "Town",
    "Phone",
    "MapLocation",
    "MapZoom",
    "About",
  }
}

func NewEditRestaurantForm() ef.Form {
  return new(EditRestaurantForm)
}

func (f *EditRestaurantForm) New() interface{} {
  return new(Restaurant)
}

func (f *EditRestaurantForm) Fetch(id int) interface{} {
  var restaurant Restaurant
  checkError(dbFetch("restaurants", "id", id, EditRestaurantFormCols(), &restaurant))
  return restaurant
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

func (f *EditRestaurantForm) Save(fi *ef.Instance) {
  checkError(dbUpsert("restaurants", fi.Id, EditRestaurantFormCols(), fi.Data))
}

// Edit Menu

func editMenu(w http.ResponseWriter, req *http.Request) {
  id := ef.GetId(req)

  switch req.Method {
  case "GET":
    restaurant := fetchRestaurantAndMenu(id)

    if string(restaurant.Menu) == "" {
      restaurant.Menu =rawJson(
`[
    {
      "id": 1,
      "name": "name",
      "desc": "desc",
      "price": 42.42
    }
  ]`)
    }

    data := struct {
        Url string
        CancelUrl string
        SavedUrl string
        Json string
    }{
        fmt.Sprintf("/admin/restaurants/%d/menu", restaurant.Id),
        "/admin/restaurants",
        "/admin/restaurants",
        string(restaurant.Menu),
    }

    templates.ElmApp(w, req, "MenuEditor", data)

  case "POST":
    body, err := ioutil.ReadAll(req.Body)
    checkError(err)

    // TODO validate menu

    _, err = db.Exec("INSERT INTO menus(restaurantId, json) VALUES($1,$2)", id, body)
    checkError(err)

    fmt.Fprint(w, "\"OK\"")
  }
}



