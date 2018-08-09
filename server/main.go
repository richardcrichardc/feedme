package main

import (
  "log"
  "github.com/gorilla/mux"
  "github.com/go-http-utils/logger"
  "net/http"
  "os"
  "feedme/server/templates"
  "feedme/server/editform"
  mw "feedme/server/middleware"
)



func main() {
  loadConfig()
  templates.Init()
  db := initDB()

  router := mux.NewRouter()

  router.HandleFunc("/{slug}", mw.GormTxHandler(db, getFrontEnd)).Methods("GET")
  router.HandleFunc("/{slug}/status", mw.GormTxHandler(db, getFrontEndStatus)).Methods("GET")
  router.HandleFunc("/placeOrder", mw.GormTxHandler(db, postPlaceOrder)).Methods("POST")
  router.HandleFunc("/{slug}/till", mw.GormTxHandler(db, getTill)).Methods("GET")
  router.HandleFunc("/{slug}/till/events", mw.GormNoTxHandler(db, getTillStream)).Methods("GET")

  router.HandleFunc("/admin/restaurants", mw.GormTxHandler(db, getRestaurants)).Methods("GET")
  router.Handle("/admin/restaurants/{id}", mw.GormTxHandler(db, editform.Handler(NewEditRestaurantForm)))
  router.HandleFunc("/admin/restaurants/{id}/menu", mw.GormTxHandler(db, editMenu)).Methods("GET", "POST")


  router.PathPrefix("/assets/").Handler(templates.AssetsHandler())

  server := mw.Recover(router, Config.Debug)
  server = logger.DefaultHandler(server)

  log.Fatal(http.ListenAndServe(":" + listenPort(), server))
}

func listenPort() string {
  port := os.Getenv("PORT")

  if port == "" {
    port = "8080"
  }

  return port
}

