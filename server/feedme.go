package main

import (
  "net/http"
  "fmt"
  "github.com/jinzhu/gorm"
)

func getFeedmeHome(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
  fmt.Fprintf(w, "<h1>Feedme</h1")
}
