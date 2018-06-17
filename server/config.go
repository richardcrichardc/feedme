package main

import (
  "encoding/json"
  "io/ioutil"
)

var Config struct {
  Debug bool
  GoogleStaticMapsKey string
}

func loadConfig() {
  configData, err := ioutil.ReadFile("config.json")
  if err != nil {
    panic(err)
  }
  err = json.Unmarshal(configData, &Config)
  if err != nil {
    panic(err)
  }
}
