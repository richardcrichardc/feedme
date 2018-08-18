port module Util.Sound exposing ( .. )

import Html exposing (..)
import Html.Attributes exposing(src, id, type_)

port playSound : String -> Cmd msg

bellView : Html msg
bellView =
  audio
    [ id "bellSound"]
    [ source [ src "/assets/bell-c9d92d.mp3", type_ "audio/mpeg" ] [] ]

bell : Cmd msh
bell =
  playSound "bellSound"
