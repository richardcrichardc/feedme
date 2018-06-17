package main

import (
  "log"
  "github.com/gorilla/mux"
  "github.com/go-http-utils/logger"
  "net/http"
  "os"
  "feedme/server/templates"
  "feedme/server/editform"
)

func main() {
  loadConfig()
  templates.Init()
  initDB()

  router := mux.NewRouter()

  router.HandleFunc("/{slug}", getFrontEnd).Methods("GET")

  router.HandleFunc("/admin/restaurants", getRestaurants).Methods("GET")
  router.Handle("/admin/restaurants/{id}", editform.Handler(NewEditRestaurantForm))
  router.HandleFunc("/admin/restaurants/{id}/menu", editMenu).Methods("GET", "POST")

  router.HandleFunc("/admin/router", getRouter).Methods("GET")


  router.PathPrefix("/assets/").Handler(templates.AssetsHandler())

  server := recoverMiddleware(router)
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

