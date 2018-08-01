package editform

import (
  "github.com/jinzhu/gorm"
  "net/http"
  "github.com/gorilla/mux"
  "strconv"
  "encoding/json"
  "fmt"
  "feedme/server/templates"
  "reflect"
  "log"
  "strings"
  "time"
 )

type Form interface {
  New() interface{}
  Layout(*Instance) Layout
  Validate(*Instance)
}

type Instance struct {
  Form Form
  Id uint
  Data interface{}

  Submission map[string]string
  Errors map[string][]string
}

type FormFactory func() Form

func Handler(db *gorm.DB, factory FormFactory) http.Handler {
  return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
    f := factory()
    fi := new(Instance)
    fi.Form = f

    fi.Id = GetId(req)

    switch req.Method {
    case "GET":
      fi.Data = f.New()

      if fi.Id != 0 {
        checkError(db.First(fi.Data, fi.Id).Error)
      }

      layout := f.Layout(fi)

      // Retrieve data for fields specified in layout
      //fmt.Fprintf(w, "FI %#v\n", fi)
      for _, row := range layout.Rows {
        row.addData(fi.Data, layout.Data)
      }

      templates.ElmApp(w, req, "EditForm", layout)
      return

    case "POST":
      var sub struct {
          Action string
          Fields map[string]string
      }

      err := json.NewDecoder(req.Body).Decode(&sub)
      if err != nil {
        panic(templates.BadRequest(err.Error()))
      }

      fi.Submission = sub.Fields
      fi.Data = f.New()
      fi.Errors = make(map[string][]string)
      f.Validate(fi)
      if fi.HasErrors() {
        json.NewEncoder(w).Encode(SubmissionResult{"ERRORS", fi.Errors})
        return
      }

      switch sub.Action {
      case "VALIDATE":
        //panic("Oh oh")
        json.NewEncoder(w).Encode(SubmissionResult{"OK", nil})
      case "SAVE":
        time.Sleep(1*time.Second) // TODO remove me

        SetID(fi.Data, fi.Id)
        checkError(db.Save(fi.Data).Error)

        json.NewEncoder(w).Encode(SubmissionResult{"SAVED", nil})
      default:
        panic(templates.BadRequest("Unknown action: " + sub.Action))
      }

    default:
      panic(templates.BadRequest("Unexected http method: " + req.Method))
    }
  })
}

func GetId(req *http.Request) uint {
  val := mux.Vars(req)["id"]

  if val == "new" {
    return 0
  }

  id, err := strconv.Atoi(val)

  if err != nil {
    panic(templates.BadRequest("Expecting 'new' or integer id, received: " + val))
  }

  return uint(id)
}


type Layout struct {
  What string
  CancelUrl, SavedUrl string
  Rows []Row
  Data map[string]string
}

type Row interface {
  addData(interface{}, map[string]string)
}

func NewLayout(what, cancelUrl, savedUrl string, rows ...Row) Layout {
  return Layout{what, cancelUrl, savedUrl, rows, map[string]string{}}
}


func Group(label string, rows ...Row) GroupRow {
  return GroupRow{label, rows}
}

type GroupRow struct {
  Label string
  Rows []Row
}

func (t GroupRow) addData(instData interface{}, layoutData map[string]string) {
  for _, row := range t.Rows {
    row.addData(instData, layoutData)
  }
}

func (t GroupRow) MarshalJSON() ([]byte, error) {
  defn := struct {
    Type, Label string
    Rows []Row
  }{"GROUP", t.Label, t.Rows}

  return json.Marshal(defn)
}


func Text(id, label string) FieldRow {
  return FieldRow{"TEXT", id, label}
}

func TextArea(id, label string) FieldRow {
  return FieldRow{"TEXTAREA", id, label}
}

type FieldRow struct {
  Type, Id, Label string
}

func (f FieldRow) addData(instData interface{}, layoutData map[string]string) {
  field := reflect.Indirect(reflect.ValueOf(instData)).FieldByName(f.Id)

  if !field.IsValid() {
    log.Panicf("editForm.Layout: Instance data is missing field '%s'", f.Id)
  }

  layoutData[f.Id] = field.Interface().(string)
}


func (fi *Instance) Validate(id, label string, validators ...Validator) {
  value := fi.Submission[id]
  var err string

  for _, validator := range validators {
    value, err = validator(value)
    if err != "" {
      err = fmt.Sprintf(err, label)
      fi.Errors[id] = []string{err}
      return
    }
  }

  field := reflect.Indirect(reflect.ValueOf(fi.Data)).FieldByName(id)

  if !field.IsValid() {
    log.Panicf("editform.Validate: Instance data is missing field '%s'", id)
  }

  field.Set(reflect.ValueOf(value))
}


type Validator func(inValue string) (outValue string, err string)

func Required(value string) (string, string) {
  if strings.TrimSpace(value) == "" {
    return value, "%s cannot be blank."
  }
  return value, ""
}

func Trim(value string) (string, string) {
  return strings.TrimSpace(value), ""
}

func checkError(err error) {
  if err != nil {
    panic(err)
  }
}


func (fi *Instance) HasErrors() bool {
  for _, errs := range fi.Errors {
    if len(errs) > 0 {
      return true
    }
  }
  return false
}

type SubmissionResult struct {
  Status string
  Errors map[string][]string
}


func SetID(data interface{}, ID uint) {
  field := reflect.Indirect(reflect.ValueOf(data)).FieldByName("ID")

  if !field.IsValid() {
    log.Panic("Instance data is missing ID")
  }

  field.Set(reflect.ValueOf(ID))
}
