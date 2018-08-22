package main

import (
  "time"
  "github.com/jinzhu/gorm"
)

type restaurantStreamId int

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
