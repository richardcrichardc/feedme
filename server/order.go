package main

import (
  //"context"
  "fmt"
  "encoding/json"
  "database/sql/driver"
  "errors"
)


type Order struct {
  RestaurantID uint `gorm:"primary_key"`
  Number uint `gorm:"primary_key"`

  Name string
  Telephone string
  MenuID uint
  Menu Menu `gorm:"association_autoupdate:false;association_autocreate:false"`
  Items OrderItems `gorm:"type:text"`
  GST Money
  Total Money
}


type OrderItems []OrderItem

type OrderItem struct {
  Id int
  Qty int
}


func (o *OrderItems) Scan(src interface{}) error {
  switch src.(type) {
  case string:
    checkError(json.Unmarshal([]byte(src.(string)), &o))
  default:
    return errors.New("Incompatible type for MenuItems")
  }
  return nil
}

func (o OrderItems) Value() (driver.Value, error) {
  return json.Marshal(o)
}


type Money int


func (o *Order) Recalc() {
  fmt.Printf("Menu: %#v\n", o.Menu)
  fmt.Printf("Order: %#v\n", o.Items)

  o.Total = 0

  for _, item := range o.Items{
    menuItem := o.Menu.Items.itemById(item.Id)
    fmt.Printf("Item: %#v\n", menuItem)
    o.Total +=  Money(item.Qty) * menuItem.Price
  }

  o.GST = integerGST(o.Total)
}

func integerGST(total Money) Money {
  intermediate := total * 15
  gst := intermediate / 100

  if (intermediate % 100) >= 50 {
    gst += 1
  }

  return gst
}


