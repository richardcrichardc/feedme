package main

import (
  "log"
  "github.com/gorilla/mux"
  "github.com/go-http-utils/logger"
  "net/http"
  "os"
  "feedme/server/templates"
)

var debugFlag bool

func main() {
  debugFlag  = true

  templates.Init()
  initDB()

  router := mux.NewRouter()
  router.Handle("/admin/restaurants/{id}", EditFormHandler(new(EditRestaurantForm)))
  router.PathPrefix("/assets/").Handler(templates.AssetsHandler())
  router.HandleFunc("/{slug}", getFrontEnd).Methods("GET")

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

