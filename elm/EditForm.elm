module EditForm exposing (..)

import Navigation
import Json.Decode as Decode
import Html exposing (..)
import Scroll

main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

-- MODEL

type alias Model =
  { flags : Decode.Value
  }

init : Decode.Value -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
  ( { flags = flags
    }
  , Scroll.scrollHash location
  )

-- UPDATE

type Msg
  = NewLocation Navigation.Location

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation menuMsg -> (model, Cmd.none)

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ div [] [ text "EditForm" ]
    , div [] [ text (toString model.flags) ]
    ]

