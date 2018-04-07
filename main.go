package main

import (
  "log"
  "github.com/gorilla/mux"
  "net/http"
  "os"
)

func main() {
  initAssets()
  initTemplates()
  initDB()

  router := mux.NewRouter()
  router.PathPrefix("/assets/").Handler(assetsHandler())
  router.HandleFunc("/{slug}", getFrontEnd).Methods("GET")
  log.Fatal(http.ListenAndServe(":" + listenPort(), router))
}

func listenPort() string {
  port := os.Getenv("PORT")

  if port == "" {
    port = "8080"
  }

  return port
}

