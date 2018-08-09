package middleware

import (
  "fmt"
  "log"
  "net/http"
  "runtime/debug"
  "feedme/server/templates"
  "github.com/jinzhu/gorm"
  "crypto/rand"
  "encoding/base64"
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

type GormTxHandlerFunc func(http.ResponseWriter, *http.Request, *gorm.DB, string)

func GormTxHandler(db *gorm.DB, handler GormTxHandlerFunc) http.HandlerFunc {
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

func GormNoTxHandler(db *gorm.DB, handler GormTxHandlerFunc) http.HandlerFunc {
  return func(w http.ResponseWriter, req *http.Request) {
    sessionID := startSession(w, req)
    handler(w, req, db, sessionID)
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
