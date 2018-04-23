package main

import (
  "fmt"
  "log"
  "net/http"
  "runtime/debug"
  "database/sql"
  "feedme/server/templates"
)

func recoverMiddleware(next http.Handler) http.Handler {
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
          case sql.ErrNoRows:
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

