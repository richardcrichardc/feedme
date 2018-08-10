package main


import (
  "errors"
  "encoding/json"
  "github.com/jinzhu/gorm"
  "database/sql/driver"
  "time"
)


type Menu struct {
  ID uint
  RestaurantID uint
  Restaurant *Restaurant `gorm:"association_autoupdate:false;association_autocreate:false"`
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

  if gorm.IsRecordNotFoundError(err) {
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
