package main


import (
  //"log"
  "github.com/jmoiron/sqlx"
  _ "github.com/lib/pq"

)

type Restaurant struct {
  Id uint

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

var db *sqlx.DB

func initDB() {
  db = sqlx.MustOpen("postgres", "dbname=feedme sslmode=disable")

  tx := db.MustBegin()

  schema := []string {
    `CREATE TABLE IF NOT EXISTS restaurants (
      id SERIAL PRIMARY KEY,
      slug text,
      name text,
      address1 text,
      address2 text,
      town text,
      phone text,
      mapLocation text,
      mapZoom text,
      about text,
      menu text
    )`,
  }

  for _, stmt := range schema {
    tx.MustExec(stmt)
  }

  checkError(tx.Commit())

}
