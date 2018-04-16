package main

import (
  //"log"
  "net/http"
  "github.com/gorilla/mux"
  "strconv"
  "encoding/json"
 )

type EditFormSpec struct {
  What string
  Rows []EditFormRow
}

type EditFormRow []byte

func (r EditFormRow) MarshalJSON() ([]byte, error){
  return r, nil
}

func MakeRow(defn interface{}) EditFormRow {
  row, err := json.Marshal(defn)
  checkError(err)
  return row
}

func EditFormString(id, label, value string) EditFormRow {
  defn := struct {Type, Id, Label, Value string}{"STRING", id, label, value}
  return MakeRow(defn)
}

func EditFormText(id, label, value string) EditFormRow {
  defn := struct {Type, Id, Label, Value string}{"TEXT", id, label, value}
  return MakeRow(defn)
}

func EditFormGap() EditFormRow {
  defn := struct {Type string}{"GAP"}
  return MakeRow(defn)
}



type EditFormErrors map[string][]string


type Form interface {
  Key(req *http.Request)
  Fetch()
  Layout() EditFormSpec
  Validate() EditFormErrors
  Save()
}


func EditFormHandler(form Form) http.Handler {
  return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
    form.Key(req)

    switch req.Method {
    case "GET":
      form.Fetch()
      formspec := form.Layout()
      elmApp(w, req, "EditForm", formspec)
      return
    case "POST":

    default:
      panic(BadRequest("Unexected http method: " + req.Method))
    }

  })
}

/*
func editRestaurant2 (w http.ResponseWriter, req *http.Request){

  id := decodeId(req)
  fetch from db

  if GET {
    generate form spec
    marshal data
    send form spec
  } else if POST {
    unmarshal data
    validate data

    if !err & save {
      save
      send saved
    } else {
      send unsaved errors
    }

  } else {
    404
  }
}
*/


func DecodeId(req *http.Request) int {
  val := mux.Vars(req)["id"]

  if val == "new" {
    return 0
  }

  id, err := strconv.Atoi(val)

  if err != nil {
    panic(BadRequest("Expecting 'new' or integer id, received: " + val))
  }

  return id
}
