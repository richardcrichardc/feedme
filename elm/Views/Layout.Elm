module Views.Layout exposing (..)

import Html exposing (..)
import Html.Attributes exposing(class, style)

navbarView : String -> Float -> List (Html msg) -> Html msg
navbarView name opacity rightHandSide =
  if opacity > 0.0 then
    div [ class "bg-light fixed-top", style [("opacity", (toString opacity)) ] ]
      [ div [ class "container d-flex" ]
        [ div [ class "px-3 py-2 align-self-center mr-auto nav-head" ] [ text name ]
        , div [ class "px-3 py-2 align-self-center" ] rightHandSide
        ]
      ]
      else
        text ""
