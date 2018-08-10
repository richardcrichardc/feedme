package main

import (
  "log"
  "github.com/gorilla/mux"
  "github.com/go-http-utils/logger"
  "net/http"
  "os"
  "feedme/server/templates"
  "feedme/server/editform"
  "github.com/jinzhu/gorm"
)



func main() {
  loadConfig()
  templates.Init()
  db := initDB()

  feedmeRouter := mux.NewRouter()
  feedmeRouter.HandleFunc("/", RequestHandler(db, getFeedmeHome)).Methods("GET")
  addCommonRoutes(feedmeRouter, db)

  restaurantRouter := mux.NewRouter()
  restaurantRouter.HandleFunc("/", RestaurantHandler(db, getFrontEnd)).Methods("GET")
  restaurantRouter.HandleFunc("/status", RestaurantHandler(db, getFrontEndStatus)).Methods("GET")
  restaurantRouter.HandleFunc("/placeOrder", RestaurantHandler(db, postPlaceOrder)).Methods("POST")
  restaurantRouter.HandleFunc("/till", RestaurantHandler(db, getTill)).Methods("GET")
  restaurantRouter.HandleFunc("/till/events", RestaurantHandlerNoTx(db, getTillStream)).Methods("GET")
  addCommonRoutes(restaurantRouter, db)

  router := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
    if hostname(req) == Config.DomainName {
      feedmeRouter.ServeHTTP(w, req)
    } else {
      restaurantRouter.ServeHTTP(w, req)
    }
  })

  server := Recover(router, Config.Debug)
  server = logger.DefaultHandler(server)

  log.Fatal(http.ListenAndServe(":" + listenPort(), server))
}



func addCommonRoutes(router *mux.Router, db *gorm.DB) {
  router.HandleFunc("/admin/restaurants", RequestHandler(db, getRestaurants)).Methods("GET")

  restaurantEditForm := editform.Handler(NewEditRestaurantForm)
  restaurantEditFormAdapter := func(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
    restaurantEditForm(w, req, tx)
  }
  router.Handle("/admin/restaurants/{id}", RequestHandler(db, restaurantEditFormAdapter))

  router.HandleFunc("/admin/restaurants/{id}/menu", RequestHandler(db, editMenu)).Methods("GET", "POST")
  router.PathPrefix("/assets/").Handler(templates.AssetsHandler())
}

func listenPort() string {
  port := os.Getenv("PORT")

  if port == "" {
    port = "8080"
  }

  return port
}




