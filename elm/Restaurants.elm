module Restaurants exposing (main)

import Loader
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, int)
import Html exposing (..)
import Html.Attributes exposing (href, class)
import Html.Events exposing (onClick)


import Bootstrap.Grid as Grid
import Bootstrap.Table as Table
import Bootstrap.Button as Button


main =
  Loader.programWithFlags
    { flagDecoder = decodeModel
    , view = view
    , update = update
    }

-- MODEL

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
  = Dup Restaurant

update : Msg -> Model -> Loader.Error -> (Model, Loader.Error, Cmd Msg)
update msg model loaderError =
  case msg of
    Dup restaurant ->
      (model ++ [restaurant], loaderError, Cmd.none)

-- VIEW

view : Model -> Html Msg
view model =
  Grid.container []
    [ h1 [] [ text "Restaurants" ]
    , p []
      [ Button.linkButton
        [ Button.primary, Button.attrs [ href "restaurants/new" ] ]
        [ text "New" ]
      ]
    , tableView model
    ]


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
      , Table.td [] [ a [ href link ] [ text " Edit" ] ]
      ]
