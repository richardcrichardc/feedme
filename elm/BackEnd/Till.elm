module BackEnd.Till exposing (..)

import Util.Loader as Loader
import Html exposing (..)
import Html.Attributes exposing(class)
import Navigation
import Json.Decode as Decode exposing (
  Value, Decoder,
  decodeValue, decodeString,
  field, andThen, fail, succeed, list, int, string)
import Views.Layout as Layout
import Models.Restaurant as Restaurant
import Models.Menu as Menu
import Json.Decode.Pipeline exposing (decode, required, hardcoded, custom)
import Util.Form exposing (spinner)
import Date
import Time exposing (every, second)
import Task
import Bootstrap.Table as Table

import Util.SSE as SSE

main =
  Loader.programWithFlags2
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

init : Value -> Navigation.Location -> (Result String Model, Cmd Msg)
init flags location =
    ( decodeValue modelDecoder flags
    , Cmd.batch
        [ Task.perform Toc Date.now
        , SSE.createEventSource "/das/till/events"
        ]
    )

-- MODEL

type alias Flags =
  { restaurant : Restaurant.Restaurant
  , orders : List Order
  }

type alias Model =
  { restaurant : Restaurant.Restaurant
  , orders : List Order
  , now : Maybe Date.Date
  }

type alias Order =
  { number : Int
  , name : String
  , telephone : String
  , menuID : Int
  , order : Menu.Order
  , created : Date.Date
  }


modelDecoder : Decoder Model
modelDecoder =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> hardcoded []
      |> hardcoded Nothing

orderDecoder : Decoder Order
orderDecoder =
    decode Order
      |> required "Number" int
      |> required "Name" string
      |> required "Telephone" string
      |> required "MenuID" int
      |> required "Items" Menu.orderDecoder
      |> custom (field "CreatedAt" string |> andThen dateDecoder)


dateDecoder : String -> Decoder Date.Date
dateDecoder dateString =
  case Date.fromString dateString of
    Ok date -> succeed date
    Err err -> fail err


type Event
  = Reset
  | NewOrder Order

decodeEvent : String -> Result String Event
decodeEvent eventStr =
  case SSE.decodeEvent eventStr of
    Ok event ->
      case event.event of
        "reset" ->
          Ok Reset
        "order" ->
          case decodeValue orderDecoder event.data of
            Ok order ->
              Ok (NewOrder order)
            Err err ->
              Err err
        _ ->
          Err ("Unsupported event: " ++ event.event)
    Err err ->
      Err err


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ every second Tick
  , SSE.ssEvents SSEvent
  ]



{-}
sseEventDecoder : SSE.SsEvent -> Msg
sseEventDecoder event =
  let
    msg =
      case event.eventType of
        "reset" ->
          Ok Reset
        "order" ->
          case decodeString orderDecoder event.data of
            Ok order ->
              Ok (NewOrder order)
            Err error ->
              Err error
        _ ->
          Err ("Unsupported event type: " ++ event.eventType)

  in
    case msg of
      Ok msg -> msg
      Err err -> Noop
-}


-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | Toc Date.Date
  | SSEvent String



update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      (model, Cmd.none)
    Tick _ ->
      (model, Task.perform Toc Date.now )
    Toc now ->
      ({ model | now = Just now }, Cmd.none)
    SSEvent value ->
      case decodeEvent value of
        Ok Reset ->
          ({ model | orders = [] }, Cmd.none)
        Ok (NewOrder order) ->
          ({ model | orders = order :: model.orders }, Cmd.none)
        Err err ->
          let
            _ = Debug.log "Bad SSEvent: " (err ++ " Event: " ++ (toString value))
          in
            (model, Cmd.none)

{-
      let
        result = SSE.decodeEvent event
                  |> Result.andThen
      in
        case result of
          Just result ->
            result
          Err err ->
            let
              _ = Debug.log "Bad SSEvent: " (err ++ " Event: " ++ (toString event))
            in
              (model, Cmd.none)

      case SSE.decodeEvent event of
        Ok event ->
          case event.event of
            "Reset" ->
              ({ model | orders = [] }, Cmd.none)
            "Order" ->
              let
                order = decodeValue orderDecoder event.data
              in
                case order of
                  Ok order ->
                    ({ model | orders = order :: model.orders }, Cmd.none)
                  Err error ->
                    let
                      _ = Debug.log "Bad Order: " (error ++ " Data: " ++ (toString event.data))
                    in
                       (model, Cmd.none)
            _ ->
-}


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbar model
    , div [ class "container section status" ]
      [ h2 [] [ text "Orders " ]
      , ordersView model.now model.orders
      ]

    ]


navbar : Model -> Html Msg
navbar model =
  let
    title = model.restaurant.name ++ " - Till"
  in
    Layout.navbarView title 1.0
      [ div [ class "clock" ] [ text (clock model.now) ]]


ordersView : Maybe Date.Date -> List Order -> Html msg
ordersView now orders =
  Table.simpleTable
    ( Table.simpleThead
      [ Table.th [] [ text "Number" ]
      , Table.th [] [ text "Time" ]
      , Table.th [] [ text "Name" ]
      , Table.th [] [ text "Phone" ]
      ]
    , Table.tbody [] (List.map (ordersLineView now) orders)
    )

ordersLineView : Maybe Date.Date -> Order -> Table.Row msg
ordersLineView now order =
  Table.tr []
    [ Table.td [] [ text (toString order.number) ]
    , Table.td [] [ text (formatCreated now order.created) ]
    , Table.td [] [ text order.name ]
    , Table.td [] [ text order.telephone ]
    ]

timeBits : Date.Date -> (String, String, String, String)
timeBits date =
  let
    h = Date.hour date
    h12 = h % 12
    hh = toString <|
            case h12 of
              0 -> 12
              _ -> h12
    m = toString (Date.minute date)
    mm = if (String.length m == 1) then
           "0" ++ m
         else
            m
    s = toString (Date.second date)
    ss = if (String.length s == 1) then
           "0" ++ s
         else
            s
    ap = if h < 12 then "am" else "pm"
  in
    (hh, mm, ss, ap)


formatCreated : Maybe Date.Date -> Date.Date -> String
formatCreated now created =
  let
    (hh, mm, ss, ap) = timeBits created
    date = case now of
            Nothing ->
              ""
            Just now ->
              if
                (Date.day now /= Date.day created)
                || (Date.month now /= Date.month created)
                || (Date.year now /= Date.year created)
              then
                (toString (Date.day created))
                ++ "-" ++ (toString (Date.month created))
                ++ "-" ++ (toString (Date.year created))
              else
                ""
  in
    date ++ " " ++ hh ++ ":" ++ mm ++ ap


clock : Maybe Date.Date -> String
clock now =
  case now of
    Nothing ->
      ""
    Just now ->
      let
        (hh, mm, ss, ap) = timeBits now
      in
        hh ++ ":" ++ mm ++ ":" ++ ss ++ ap
