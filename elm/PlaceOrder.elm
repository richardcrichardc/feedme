port module PlaceOrder exposing (..)

import Navigation

import Menu
import Rails

import Html exposing (..)

port scrollIntoView : String -> Cmd msg


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
  { target : Rails.FormTarget
  , menu_id : Int
  , menu : Maybe Menu.Menu
  , order : Menu.Order
  }

type alias FlagFields =
  { menu_id : Int
  , menu : Menu.Menu
  }

init : Rails.FormFlags FlagFields -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
  ( { target = flags.target
    , menu_id = flags.fields.menu_id
    , menu = Just flags.fields.menu
    , order = []
    }
  , scrollHash location
  )

scrollHash : Navigation.Location -> Cmd Msg
scrollHash location =
  if location.hash == "" then
    Cmd.none
  else
    scrollIntoView (String.dropLeft 1 location.hash)

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | MenuMsg Menu.Msg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation menuMsg -> (model, Cmd.none)

    MenuMsg (Menu.Add item) ->
          ( { model | order = Menu.orderAdd item model.order }
          , Cmd.none
          )

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ div [] [ Html.map MenuMsg (Menu.maybeSinglePageView model.menu model.order) ]
    ]

