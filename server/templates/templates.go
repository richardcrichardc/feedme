package templates

import (
  "html/template"
  "net/http"
  "io/ioutil"
  "encoding/json"
)

type BadRequest string

var assetMap map[string]string
var Templates *template.Template

func Init() {
  // Init Assets
  assetMapJson, err := ioutil.ReadFile("assets-hashed/fileMap.json")
  checkError(err)

  assetMap = make(map[string]string)
  checkError(json.Unmarshal(assetMapJson, &assetMap))

  // Init templates
  Templates = template.New("root")

  Templates.Funcs(template.FuncMap{
    "asset": AssetPath,
  })

  _, err = Templates.ParseGlob("templates/*.tmpl")
  checkError(err)

  initAssets()
}

func initAssets() {
}

func AssetsHandler() http.Handler {
  return http.StripPrefix("/assets/", http.FileServer(http.Dir("assets-hashed")))
}

func AssetPath(asset string) string {
  return assetMap[asset]
}

func ElmApp(w http.ResponseWriter, req *http.Request, appName string, flags interface{}) {
  var d struct {
    App template.JS
    Flags template.JS
  }

  flagsJson, err := json.MarshalIndent(flags, "", "  ")
  checkError(err)

  d.App = template.JS(appName)
  d.Flags = template.JS(string(flagsJson))

  Templates.Lookup("elm-spa.tmpl").Execute(w, d)
}

func checkError(err error) {
  if err != nil {
    panic(err)
  }
}
