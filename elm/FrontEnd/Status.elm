module FrontEnd.Status exposing (..)

import Util.Loader as Loader
import Html exposing (..)
import Html.Attributes exposing(class)
import Navigation
import Json.Decode as Decode exposing (Value, Decoder, decodeValue)
import Views.Layout as Layout
import Models.Restaurant as Restaurant
import Models.Menu as Menu
import Models.OrderStatus as OrderStatus
import Json.Decode.Pipeline exposing (decode, required, hardcoded, custom)
import Util.Form exposing (spinner)
import Util.SSE as SSE
import Time
import Task

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
        [ Task.perform Tick Time.now
        ,SSE.createEventSource "/status/stream"
        ]
    )

-- MODEL

type alias Model =
  { restaurant : Restaurant.Restaurant
  , menu : Menu.Menu
  , order : Menu.Order
  , now : Time.Time
  , status : OrderStatus.OrderStatus
  }


decodeModel : Decoder Model
decodeModel =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> required "Menu" Menu.menuDecoder
      |> required "Order" Menu.orderDecoder
      |> hardcoded 0
      |> custom OrderStatus.statusDecoder


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Time.every Time.second Tick
  , SSE.ssEvents SSEvent
  ]

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | SSEvent String

type Event
  = StatusUpdateEvent OrderStatus.StatusUpdate

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      ( model, Cmd.none)

    Tick now ->
      ({ model | now = now }, Cmd.none)

    SSEvent value ->
      case decodeEvent value of
        Ok (StatusUpdateEvent update) ->
          ({ model | status = update.status }
          , Cmd.none)
        Err err ->
          let
            _ = Debug.log "Bad SSEvent: " (err ++ " Event: " ++ (toString value))
          in
            (model, Cmd.none)


decodeEvent : String -> Result String Event
decodeEvent eventStr =
  case SSE.decodeEvent eventStr of
    Ok event ->
      let
        _ = Debug.log "Event" event
      in
        case event.event of
          "statusUpdate" ->
            case decodeValue OrderStatus.statusUpdateDecoder event.data of
              Ok update ->
                Ok (StatusUpdateEvent update)
              Err err ->
                Err err
          _ ->
            Err ("Unsupported event: " ++ event.event)
    Err err ->
      Err err


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ Layout.navbarView model.restaurant.name 1.0 []
    , div [ class "container section status" ]
      [ h2 [] [ text "Order Status" ]
      , p [] [ text "Your order has been received." ]
      , statusView model.now model.status
      {-, p [] [ text "Your order has been received."]
      , p []
          [ text "Estimated ready time: "
          , text (toString model.status)
          , text "pending "
          , spinner
          ]
      -}
      , Menu.invoiceView model.menu model.order
      ]

    ]

statusView : Time.Time -> OrderStatus.OrderStatus -> Html Msg
statusView now status =
  case status of
    OrderStatus.New _ ->
      p []
        [ spinner
        , text " Standby for an estimate of when your order will be ready."
        ]

    OrderStatus.Expected expected ->
      let
        minutes = ((expected - now)
          |> Time.inMinutes
          |> floor
          |> toString )
      in
        p []
          [ spinner
          , text (" We expect your order to be be ready in " ++ minutes ++ " minutes.")
          ]

    OrderStatus.Ready ->
      p []
        [ spinner
        , text "Your order is now ready to be picked up."
        ]

    OrderStatus.PickedUp ->
      p []
        [ text "Thanks for picking up your meal. We hope you enjoy it!" ]

    OrderStatus.Rejected ->
      p []
        [ text "Sorry, your order has been rejected. Please telephone the shop for more details." ]
