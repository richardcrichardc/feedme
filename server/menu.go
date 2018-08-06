package main


import (
  "errors"
  "encoding/json"
  "github.com/jinzhu/gorm"
  "database/sql/driver"
  "io/ioutil"
  "net/http"
  "feedme/server/templates"
  ef "feedme/server/editform"
  "time"
  "fmt"
)


type Menu struct {
  ID uint
  RestaurantID uint
  Restaurant *Restaurant `gorm:"preload:true;association_autoupdate:false;association_autocreate:false"`
  Items MenuItems `gorm:"type:text"`

  CreatedAt time.Time
  UpdatedAt time.Time
}

type MenuItems []MenuItem

type MenuItem struct {
  Id int
  Name string
  Desc string
  Price Money
}


func fetchMenuForRestaurantID(tx *gorm.DB, ID uint) *Menu {
  return fetchMenuWhere(tx, "restaurant_id = ?", ID)
}

func fetchMenuForRestaurantSlug(tx *gorm.DB, slug string) *Menu {
  return fetchMenuWhere(tx, "restaurants.slug = ?", slug)
}

func fetchMenuWhere(tx *gorm.DB, where interface{}, args ...interface{}) *Menu {
  var menu Menu

  err := (tx.Preload("Restaurant").Order("ID desc").Where(where, args...).
          Joins("LEFT JOIN restaurants ON restaurants.id = menus.restaurant_id").
          First(&menu).Error)

  if err == gorm.ErrRecordNotFound {
    return nil
  }

  checkError(err)

  return &menu
}


func (m *MenuItems) Scan(src interface{}) error {
  switch src.(type) {
  case string:
    checkError(json.Unmarshal([]byte(src.(string)), &m))
  default:
    return errors.New("Incompatible type for MenuItems")
  }
  return nil
}

func (m MenuItems) Value() (driver.Value, error) {
  return json.Marshal(m)
}


func fetchMenu(tx *gorm.DB, id uint) *Menu {
  var menu Menu
  checkError(tx.First(&menu, id).Error)
  return &menu
}

func (m *MenuItems)itemById(id int) *MenuItem {
  for _, item := range *m {
    if item.Id == id {
      return &item
    }
  }
  return nil
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
