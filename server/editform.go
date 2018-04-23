package main

import (
  "net/http"
  "github.com/gorilla/mux"
  "strconv"
  "encoding/json"
  "fmt"
 )

type EditFormLayout struct {
  What string
  Rows []EditFormRow
  Data map[string]string
}

type EditFormRow []byte

func (r EditFormRow) MarshalJSON() ([]byte, error){
  return r, nil
}

type EditFormData struct {
  id, value string
}

type EditFormRowData struct {
  row EditFormRow
  data []EditFormData
}

func NewEditFormLayout(what string) (f *EditFormLayout) {
  f = new(EditFormLayout)
  f.What = what
  f.Data = make(map[string]string)
  return f
}

func (f *EditFormLayout) AddRow(rowData EditFormRowData) {
  f.Rows = append(f.Rows, rowData.row)
  for _, d := range rowData.data {
    f.Data[d.id] = d.value
  }
}

func MakeRowData(rowDefn interface{}, data []EditFormData) EditFormRowData {
  row, err := json.Marshal(rowDefn)
  checkError(err)
  return EditFormRowData{row, data}
}

func EditFormString(id, label, value string) EditFormRowData {
  defn := struct {Type, Id, Label string}{"STRING", id, label}
  return MakeRowData(defn, []EditFormData{{id, value}})
}

func EditFormText(id, label, value string) EditFormRowData {
  defn := struct {Type, Id, Label string}{"TEXT", id, label}
  return MakeRowData(defn, []EditFormData{{id, value}})
}

func EditFormGroup(label string, rowData... EditFormRowData) EditFormRowData {
  var rows []EditFormRow
  var data []EditFormData

  for _, rowData := range rowData {
    rows = append(rows, rowData.row)
    data = append(data, rowData.data...)
  }

  defn := struct {
    Type, Label string
    Rows []EditFormRow
  }{"GROUP", label, rows}

  return MakeRowData(defn, data)
}

type EditFormSubmission struct {
  Action string
  Fields map[string]string
}

type EditFormErrors map[string][]string


type Form interface {
  Key(req *http.Request)
  Fetch()
  Layout() *EditFormLayout
  Validate(map[string]string) EditFormErrors
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
      var submission EditFormSubmission
      err := json.NewDecoder(req.Body).Decode(&submission)
      checkError(err)
      fmt.Fprintf(w, "%#v", submission)

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
