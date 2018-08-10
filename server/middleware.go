package main

import (
  "fmt"
  "log"
  "net/http"
  "runtime/debug"
  "feedme/server/templates"
  "github.com/jinzhu/gorm"
  "crypto/rand"
  "encoding/base64"
  "strings"
)

func Recover(next http.Handler, debugFlag bool) http.Handler {
  return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
    defer func() {
      if err := recover(); err != nil {
        log.Printf("%s\n%s", err, debug.Stack())

        var code int
        var msg string
        switch err.(type) {
        case templates.BadRequest:
          code = 400
          msg = "Bad Request"
        default:
          switch err {
          case gorm.ErrRecordNotFound:
            code = 404
            msg = "Not Found"
          default:
            code = 500
            msg = "Internal Server Error"
          }
        }

        w.WriteHeader(code)
        fmt.Fprintf(w, "%d %s\n", code, msg)

        if debugFlag {
          fmt.Fprintf(w, "\n%s\n%s", err, debug.Stack())
        }
      }
    }()

    next.ServeHTTP(w, req)
  })
}


// TODO rename these, not just Gorm Tx

type RequestHandlerFunc func(http.ResponseWriter, *http.Request, *gorm.DB, string)
type RestaurantHandlerFunc func(http.ResponseWriter, *http.Request, *gorm.DB, string, *Restaurant)

func RequestHandler(db *gorm.DB, handler RequestHandlerFunc) http.HandlerFunc {
  return func(w http.ResponseWriter, req *http.Request) {
    tx := db.Begin()
    fmt.Println("Begin transaction")

    defer func() {
        if err := recover(); err != nil {
          tx.Rollback()
          fmt.Println("Rollback transaction")
          panic(err)
        } else {
          tx.Commit()
          fmt.Println("Commit transaction")
        }
    }()

    sessionID := startSession(w, req)
    handler(w, req, tx, sessionID)
  }
}

func RestaurantHandler(db *gorm.DB, handler RestaurantHandlerFunc) http.HandlerFunc {
  return RequestHandler(db, func(w http.ResponseWriter, req *http.Request, tx *gorm.DB, sessionID string) {
    restaurant := RestaurantFromHostname(tx, req)
    handler(w, req, tx, sessionID, restaurant)
  })
}

func RestaurantHandlerNoTx(db *gorm.DB, handler RestaurantHandlerFunc) http.HandlerFunc {
  return func(w http.ResponseWriter, req *http.Request) {
    sessionID := startSession(w, req)
    restaurant := RestaurantFromHostname(db, req)
    handler(w, req, db, sessionID, restaurant)
  }
}

func startSession(w http.ResponseWriter, req *http.Request) string {
  var cookie *http.Cookie

  cookie, err := req.Cookie("session")

  if err != nil {
    cookie = &http.Cookie{
      Name: "session",
      Value: randomIdString(),
      HttpOnly: true,
    }
    http.SetCookie(w, cookie)
  }

  return cookie.Value
}

func randomIdString() string {
  id := make([]byte, 12)

  _, err := rand.Read(id)
  if err != nil {
    panic(err)
  }

  return base64.URLEncoding.EncodeToString(id)
}

func RestaurantFromHostname(db *gorm.DB, req *http.Request) *Restaurant {
  var slug string
  host := hostname(req)
  domainName := Config.DomainName
  splitPosition := len(host) - len(domainName) - 1

  if splitPosition > 0 && host[splitPosition] == '.' && host[splitPosition+1:] == domainName {
    slug = host[0:splitPosition]
  } else {
    panic(gorm.ErrRecordNotFound)
  }

  return fetchRestaurantBySlug(db, slug)
}

func hostname(req *http.Request) string {
  // req.Host may be in format hostname:portnumber
  return strings.Split(req.Host, ":")[0]
}

func port(req *http.Request) string {
  // req.Host may be in format hostname:portnumber
  parts := strings.Split(req.Host, ":")

  if len(parts) == 2 {
    return ":" + parts[1]
  } else {
    return ""
  }


}
