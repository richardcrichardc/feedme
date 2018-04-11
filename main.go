package main

import (
  "log"
  "github.com/gorilla/mux"
  "github.com/go-http-utils/logger"
  "net/http"
  "os"
)

var debugFlag bool

func main() {
  debugFlag  = true

  initAssets()
  initTemplates()
  initDB()

  router := mux.NewRouter()
  router.HandleFunc("/admin/restaurants/{id}",editRestaurant)
  router.PathPrefix("/assets/").Handler(assetsHandler())
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

