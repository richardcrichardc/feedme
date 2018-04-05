package main

import (
  "log"
  "github.com/gorilla/mux"
  "net/http"
  "os"
)

func main() {
  initTemplates()
  initDB()

  router := mux.NewRouter()
  router.PathPrefix("/assets/").HandlerFunc(assets)
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

