module Restaurants exposing (main)

import Navigation
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, int)
import Html exposing (..)
import Html.Attributes exposing (href, class)

import Bootstrap.Grid as Grid
import Bootstrap.Table as Table
import Bootstrap.Button as Button


main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

init : Value -> Navigation.Location -> (ResultModel, Cmd Msg)
init flags location =
  ( decodeValue decodeModel flags, Cmd.none)

-- MODEL

type alias ResultModel = Result String Model

type alias Model = List Restaurant

type alias Restaurant =
  { id : Int
  , slug : String
  , name : String
  }

decodeModel : Decoder Model
decodeModel = list decodeRestaurant

decodeRestaurant : Decoder Restaurant
decodeRestaurant = Decode.map3 Restaurant
    (field "Id" int )
    (field "Slug" string)
    (field "Name" string)

-- UPDATE

type Msg
  = NewLocation Navigation.Location

update : Msg -> ResultModel -> (ResultModel, Cmd Msg)
update msg model = (model, Cmd.none)


-- VIEW

view : ResultModel -> Html Msg
view maybeModel =
  Grid.container [] (
    [ h1 [] [ text "Restaurants" ] ] ++
    case maybeModel of
      Ok model ->
        [ p []
          [ Button.linkButton
            [ Button.primary, Button.attrs [ href "restaurants/new" ] ]
            [ text "New" ]
          ]
        , tableView model
        ]
      Err msg ->
        [ div [] [ text  ("Load error: " ++ msg) ] ]
  )

tableView : Model -> Html Msg
tableView model =
  Table.simpleTable
    ( Table.simpleThead
        [ Table.th [] [ text "Slug" ]
        , Table.th [] [ text "Name" ]
        , Table.th [] [ ]
        ]
    , Table.tbody []
      (List.map rowView model)
    )

rowView : Restaurant -> Table.Row Msg
rowView restaurant =
  let
    link =  "restaurants/" ++ (toString restaurant.id)
  in
    Table.tr []
      [ Table.td [] [ text restaurant.slug ]
      , Table.td [] [ text restaurant.name ]
      , Table.td []
          [ a [ href link ] [ text " Edit" ]
          ]
      ]
