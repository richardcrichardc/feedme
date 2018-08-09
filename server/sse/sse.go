package sse

// Derived from https://github.com/julienschmidt/sse/blob/master/sse.go - MIT Licence

import (
  "net/http"
  "time"
  "log"
  "encoding/json"
)

type Event struct {
  Event string
  Data interface{}
}

func Stream(w http.ResponseWriter, events chan Event) {
  // We need to be able to flush for SSE
  fl, ok := w.(http.Flusher)
  if !ok {
    http.Error(w, "Flushing not supported", http.StatusNotImplemented)
    return
  }

  // Returns a channel that blocks until the connection is closed
  //cn, ok := w.(http.CloseNotifier)
  //if !ok {
  //  http.Error(w, "Closing not supported", http.StatusNotImplemented)
  //  return
  //}
  //close := cn.CloseNotify()

  // Set headers for SSE
  h := w.Header()
  h.Set("Cache-Control", "no-cache")
  h.Set("Connection", "keep-alive")
  h.Set("Content-Type", "text/event-stream")


  ticker := time.NewTicker(30 * time.Second)
  defer ticker.Stop()


  for {
    var err error

    select {
    //case <-close:
      // Disconnect the client when the connection is closed
    //  return
    case <- ticker.C:
      _, err = w.Write([]byte(": keep-alive\n\n"))

    case event := <-events:

      eventData, err := json.Marshal(event)
      if (err != nil) {
        panic(err)
      }

      _, err = w.Write([]byte("data: "))
      _, err = w.Write(eventData)
      _, err = w.Write([]byte("\n\n"))

    }

    if err != nil {
      log.Printf("SSE connection lost: %#v", err)
      return
    }

    fl.Flush()
  }
}
