package main


import (
  "log"
  "github.com/jinzhu/gorm"
  _ "github.com/jinzhu/gorm/dialects/postgres"
)

type Restaurant struct {
  Id uint `gorm:"primary_key"`

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

var db *gorm.DB

func initDB() {
  var err error
  db, err = gorm.Open("postgres", "dbname=feedme sslmode=disable")
  if err != nil {
    log.Fatalf("Failed to connect to database: %s", err)
  }

  db.AutoMigrate(&Restaurant{})
}
