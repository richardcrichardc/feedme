package main


import (
  "github.com/jinzhu/gorm"
  _ "github.com/lib/pq"
  "gopkg.in/gormigrate.v1"
  "log"
  "time"
)

func initDB() *gorm.DB {
  var err error

  db, err := gorm.Open("postgres", "dbname=feedme sslmode=disable")
  checkError(err)
  log.Printf("DB: %v", db)

  db.LogMode(true)


  options := &gormigrate.Options{
    TableName:      "migrations",
    IDColumnName:   "id",
    IDColumnSize:   255,
    UseTransaction: true,
  }


  m := gormigrate.New(db, options, []*gormigrate.Migration{
    {
      ID: "1",
      Migrate: func(tx *gorm.DB) error {
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

        type RestaurantOrderNumber struct {
          RestaurantID uint `gorm:"primary_key"`
          LastOrderNumber uint
        }

        type Menu struct {
          ID uint
          RestaurantID uint
          Restaurant *Restaurant `gorm:"association_autoupdate:false;association_autocreate:false"`
          Items MenuItems `gorm:"type:text"`

          CreatedAt time.Time
          UpdatedAt time.Time
        }

      type Order struct {
          RestaurantID uint `gorm:"primary_key"`
          Number uint `gorm:"primary_key"`

          Name string
          Telephone string
          MenuID uint
          Menu *Menu `gorm:"association_autoupdate:false;association_autocreate:false"`
          Items OrderItems `gorm:"type:text"`
          GST Money
          Total Money

          SessionID string `gorm:"not null"`
          CreatedAt time.Time `gorm:"not null"`
        }

        err :=  tx.AutoMigrate(&Restaurant{}).Error
        if err != nil { return err }

        err = tx.AutoMigrate(&RestaurantOrderNumber{}).Error
        if err != nil { return err }

        err = tx.AutoMigrate(&Menu{}).Error
        if err != nil { return err }

        err = tx.Model(&Menu{}).AddForeignKey("restaurant_id", "restaurants(id)", "RESTRICT", "RESTRICT").Error
        if err != nil { return err }

        err = tx.AutoMigrate(&Order{}).Error
        if err != nil { return err }

        err = tx.Model(&Order{}).AddForeignKey("restaurant_id", "restaurants(id)", "RESTRICT", "RESTRICT").Error
        if err != nil { return err }

        err = tx.Model(&Order{}).AddForeignKey("menu_id", "menus(id)", "RESTRICT", "RESTRICT").Error
        if err != nil { return err }

        err = tx.Model(&Order{}).AddIndex("orders_session_id_create_at_index", "session_id", "created_at").Error
        return err
      },
    },
  })

  checkError(m.Migrate())

  return db
}

