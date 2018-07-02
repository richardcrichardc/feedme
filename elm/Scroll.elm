port module Scroll exposing (..)

import Navigation

port scrollIntoView : String -> Cmd msg
port scrollPosition : ((Int, Int, Int) -> msg) -> Sub msg

scrollHash : Navigation.Location -> Cmd msg
scrollHash location =
  if location.hash == "" then
    Cmd.none
  else
    scrollIntoView (String.dropLeft 1 location.hash)
