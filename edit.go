package main

import (
)

type EditForm struct {
  What string
  Rows []EditRow
  Data interface{}
}

type EditRow struct {
  Id string
  Label string
  Type string
}
