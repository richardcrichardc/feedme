package main

import (
  "errors"
)

type rawJson []byte

func (r rawJson) MarshalJSON() ([]byte, error){
  return r, nil
}

func (r *rawJson) Scan(src interface{}) error {
  switch src.(type) {
  case string:
    *r = []byte(src.(string))
  case []byte:
    *r = src.([]byte)
  default:
    return errors.New("Incompatible type for rawJson")
  }
  return nil
}

