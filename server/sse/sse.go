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

func Send(address interface{}, event *Event) {
  actionChan <- action{sendAction, address, event, nil}
}

func Stream(w http.ResponseWriter, initialEvents []Event, address interface{}) {
  // We need to be able to flush for SSE
  fl, ok := w.(http.Flusher)
  if !ok {
    http.Error(w, "Flushing not supported", http.StatusNotImplemented)
    return
  }

  // Subscribe and unsubscribe from events
  events := make(chan Event, 64)
  actionChan <- action{subscribeAction, address, nil, events}
  defer func() { actionChan <- action{unsubscribeAction, address, nil, events} }()

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

  // Send initial events
  for _, event := range initialEvents {
    writeEvent(w, event)
  }
  fl.Flush()

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
      err = writeEvent(w, event)
    }

    if err != nil {
      log.Printf("SSE connection lost: %#v", err)
      return
    }

    fl.Flush()
  }
}

func writeEvent(w http.ResponseWriter, event Event) error {
  var err error

  eventData, err := json.Marshal(event)
  if (err != nil) {
    panic(err)
  }

  _, err = w.Write([]byte("data: "))
  _, err = w.Write(eventData)
  _, err = w.Write([]byte("\n\n"))

  return err
}

const (
  sendAction = iota
  subscribeAction
  unsubscribeAction
)

type action struct {
  actionType int
  address interface{}
  event *Event
  stream chan Event
}

var actionChan chan action

func init() {
  actionChan = make(chan action, 1024)
  go service()
}

func service() {
  streamsMap := make(map[interface{}][]chan Event)

  for {
    a := <- actionChan

    switch a.actionType {
    case sendAction:
      streams := streamsMap[a.address]

      if streams != nil {
        for _, stream := range streams {
          stream <- *a.event
        }
      }

    case subscribeAction:
      streams := streamsMap[a.address]
      if streams == nil {
        streams = make([]chan Event, 0)
      }
      streamsMap[a.address] = append(streams, a.stream)

    case unsubscribeAction:
      origStreams := streamsMap[a.address]
      if origStreams != nil {
        newStreams := make([]chan Event, 0)

        for _, s := range origStreams {
          if s != a.stream {
            newStreams = append(newStreams, s)
          }
        }

        streamsMap[a.address] = newStreams
      }

    default:
      log.Panicf("Bad sse action: %#v", a.actionType)
    }
  }
}
