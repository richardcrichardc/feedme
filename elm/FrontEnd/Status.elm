module FrontEnd.Status exposing (..)

import Util.Loader as Loader
import Html exposing (..)
import Html.Attributes exposing(class)
import Navigation
import Json.Decode as Decode exposing (Value, Decoder, decodeValue)
import Views.Layout as Layout
import Models.Restaurant as Restaurant
import Models.Menu as Menu
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)
import Util.Form exposing (spinner)

main =
  Loader.programWithFlags2
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

init : Value -> Navigation.Location -> (Result String Model, Cmd Msg)
init value location =
    ( decodeValue decodeModel value
    , Cmd.batch
        [
        ]
    )

-- MODEL

type alias Model =
  { restaurant : Restaurant.Restaurant
  , menu : Menu.Menu
  , order : Menu.Order
  }


decodeModel : Decoder Model
decodeModel =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> required "Menu" Menu.menuDecoder
      |> required "Order" Menu.orderDecoder


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [
  ]

-- UPDATE

type Msg
  = NewLocation Navigation.Location

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      ( model
      , Cmd.none
      )




-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ Layout.navbarView model.restaurant.name 1.0 []
    , div [ class "container section status" ]
      [ h2 [] [ text "Order Status" ]
      , p [] [ text "Your order has been received."]
      , p []
          [ text "Estimated ready time: "
          , text "pending "
          , spinner
          ]
      , Menu.invoiceView model.menu model.order
      ]

    ]

