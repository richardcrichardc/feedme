package main


import (
  //"log"
  "github.com/jmoiron/sqlx"
  _ "github.com/lib/pq"

)

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
