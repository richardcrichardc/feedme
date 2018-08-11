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
import Bootstrap.Table as Table exposing (cellAttr)
import Bootstrap.Button as Button
import Bootstrap.Modal as Modal

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
        , SSE.createEventSource "/till/events"
        ]
    )

-- MODEL

type alias Model =
  { restaurant : Restaurant.Restaurant
  , orders : List Order
  , now : Maybe Date.Date
  , modalOrder : Maybe Order
  }

type alias Order =
  { number : Int
  , name : String
  , telephone : String
  , menu : Menu.Menu
  , order : Menu.Order
  , created : Date.Date
  }


modelDecoder : Decoder Model
modelDecoder =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> hardcoded []
      |> hardcoded Nothing
      |> hardcoded Nothing

orderDecoder : Decoder Order
orderDecoder =
    decode Order
      |> required "Number" int
      |> required "Name" string
      |> required "Telephone" string
      |> required "MenuItems" Menu.menuDecoder
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
      let
        _ = Debug.log "Event" event
      in
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


-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | Toc Date.Date
  | SSEvent String
  | SelectOrder Order
  | CloseModal



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
    SelectOrder order ->
      ({ model | modalOrder = Just order }, Cmd.none)
    CloseModal ->
      ({ model | modalOrder = Nothing }, Cmd.none)


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbarView model
    , modalView model.modalOrder
    , div [ class "container section status" ]
      [ h2 [] [ text "Orders " ]
      , ordersView model.now model.orders
      ]

    ]


navbarView : Model -> Html Msg
navbarView model =
  let
    title = model.restaurant.name ++ " - Till"
  in
    Layout.navbarView title 1.0
      [ div [ class "clock" ] [ text (clock model.now) ]]


ordersView : Maybe Date.Date -> List Order -> Html Msg
ordersView now orders =
  Table.simpleTable
    ( Table.simpleThead
      [ Table.th [ cellAttr (class "text-center") ] [ text "#" ]
      , Table.th [] [ text "Time" ]
      , Table.th [] [ text "Name" ]
      , Table.th [] [ text "Phone" ]
      , Table.th [ cellAttr (class "text-center") ] [ text "Items" ]
      , Table.th [ cellAttr (class "text-right") ] [ text "Total" ]
      , Table.th [] [ text "" ]
      ]
    , Table.tbody [] (List.map (ordersLineView now) orders)
    )

ordersLineView : Maybe Date.Date -> Order -> Table.Row Msg
ordersLineView now order =
  let
    (totalItems, totalPrice) = Menu.orderTotals order.menu order.order
  in
    Table.tr []
      [ Table.td [ cellAttr (class "text-center") ] [ text (toString order.number) ]
      , Table.td [] [ text (formatCreated now order.created) ]
      , Table.td [] [ text order.name ]
      , Table.td [] [ text order.telephone ]
      , Table.td [ cellAttr (class "text-center") ] [ text totalItems ]
      , Table.td [ cellAttr (class "text-right") ] [ text totalPrice ]
      , Table.td [ cellAttr (class "text-right") ] [
          Button.button
            [ Button.small, Button.primary, Button.onClick (SelectOrder order)]
            [ text "Details" ]
        ]
      ]


modalView : Maybe Order -> Html Msg
modalView order =
  case order of
    Nothing ->
      text ""
    Just order ->
      let
        title = "Order #" ++ (toString order.number) ++ " - " ++ order.name ++ " (" ++ order.telephone ++ ")"
      in
        Modal.config CloseModal
          |> Modal.large
          |> Modal.h5 [] [ text title ]
          |> Modal.body [ class "d-flex flex-row" ]
              [ div
                  [ class "flex-grow-1" ]
                  [ Menu.invoiceView order.menu order.order ]
              , div
                  [ ]
                  [ Button.button [ Button.primary ] [ text "Button"] ]
              ]
          |> Modal.view Modal.shown


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
