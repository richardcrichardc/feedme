package main

import (
  "github.com/gorilla/mux"
  "net/http"
  "encoding/json"
  "html/template"
)




func getFrontEnd(w http.ResponseWriter, req *http.Request) {

 var d struct {
    Fields struct {
      MenuId int `json:"menu_id"`
      Menu interface{} `json:"menu"`
    } `json:"fields"`
    Target struct {
      Method string `json:"method"`
      Url string `json:"url"`
      AuthToken string `json:"auth_token"`
    } `json:"target"`
  }
/*
      var flags = {
        "fields": {
          "menu_id": <%== safe_script_to_json(@menu.id) %>,
          "menu": <%== safe_script_json(@menu.json) %>
        },
        "target": <%== safe_script_to_json({
          'method' => 'POST',
          'url' => request.fullpath,
          'auth_token' => form_authenticity_token
        }) %>
      }
*/

  slug := mux.Vars(req)["slug"]

  restaurant := fetchRestaurantBySlug(slug)

  d.Fields.MenuId = 42

  err := json.Unmarshal([]byte(restaurant.Menu), &d.Fields.Menu)
  if err != nil {
    panic(err)
  }

  jsonBytes, _ := json.MarshalIndent(d, "", "  ")

  //w.Header().Set("Content-Type", "text/plain")
  templates.Lookup("elm-spa.tmpl").Execute(w, template.JS(string(jsonBytes)))

}
