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
  , now : Date.Date
  , modalOrder : Maybe Order
  , expected : Int
  }

type alias Order =
  { number : Int
  , name : String
  , telephone : String
  , menu : Menu.Menu
  , order : Menu.Order
  , created : Date.Date
  , status : OrderStatus
  }

type OrderStatus
  = New
  | Expected Date.Date
  | Ready
  | Rejected


modelDecoder : Decoder Model
modelDecoder =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> hardcoded []
      |> hardcoded (Date.fromTime 0)
      |> hardcoded Nothing
      |> hardcoded 15

orderDecoder : Decoder Order
orderDecoder =
    decode Order
      |> required "Number" int
      |> required "Name" string
      |> required "Telephone" string
      |> required "MenuItems" Menu.menuDecoder
      |> required "Items" Menu.orderDecoder
      |> custom (field "CreatedAt" string |> andThen dateDecoder)
      |> hardcoded New


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


addMinutes : Date.Date -> Int -> Date.Date
addMinutes date minutes =
    Date.fromTime ((Date.toTime date) + (toFloat minutes * Time.minute))


updateOrderStatus : List Order -> Order -> OrderStatus -> List Order
updateOrderStatus orders order status =
  let
    updatedOrder = { order | status = status }
    replace original =
      if original.number == order.number then
        updatedOrder
      else
        original
    updatedOrders = List.map replace orders
  in
    sortOrders updatedOrders


sortOrders : List Order -> List Order
sortOrders orders =
  List.sortWith orderComparison orders

orderComparison : Order -> Order -> Basics.Order
orderComparison a b =
  case a.status of
    New ->
      case b.status of
        New -> compareDate a.created b.created
        Expected _ -> LT
        Ready -> LT
        Rejected -> LT
    Expected aExpected ->
      case b.status of
        New -> GT
        Expected bExpected -> compareDate aExpected bExpected
        Ready -> LT
        Rejected -> LT
    Ready ->
        case b.status of
      New -> GT
      Expected _ -> GT
      Ready -> EQ
      Rejected -> LT
    Rejected ->
      case b.status of
        New -> GT
        Expected _ -> GT
        Ready -> GT
        Rejected -> GT


compareDate : Date.Date -> Date.Date -> Basics.Order
compareDate a b =
  compare (Date.toTime a) (Date.toTime b)


invertOrder: Basics.Order -> Basics.Order
invertOrder order =
  case order of
    LT -> GT
    EQ -> EQ
    GT -> LT



-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | Toc Date.Date
  | SSEvent String
  | SelectOrder Order
  | CloseModal
  | SetStatus Order OrderStatus
  | ExpectedDelta Int



update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      (model, Cmd.none)

    Tick _ ->
      (model, Task.perform Toc Date.now )

    Toc now ->
      ({ model | now = now }, Cmd.none)

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

    SetStatus order status ->
      ({ model |
          orders = updateOrderStatus model.orders order status,
          modalOrder = Nothing
       }
      , Cmd.none)

    ExpectedDelta delta ->
      ({ model | expected = model.expected + delta }, Cmd.none)


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbarView model
    , modalView model.now model.modalOrder model.expected
    , div [ class "container section" ]
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


ordersView : Date.Date -> List Order -> Html Msg
ordersView now orders =
  Table.simpleTable
    ( Table.simpleThead
      [ Table.th [ cellAttr (class "text-center") ] [ text "#" ]
      , Table.th [] [ text "Name" ]
      , Table.th [ cellAttr (class "text-center") ] [ text "Items" ]
      , Table.th [ cellAttr (class "text-right") ] [ text "Total" ]
      , Table.th [ cellAttr (class "text-center") ] [ text "Status" ]
      , Table.th [] [ text "" ]
      ]
    , Table.tbody [] (List.map (ordersLineView now) orders)
    )

ordersLineView : Date.Date -> Order -> Table.Row Msg
ordersLineView now order =
  let
    (totalItems, totalPrice) = Menu.orderTotals order.menu order.order
  in
    Table.tr []
      [ Table.td [ cellAttr (class "text-center") ] [ text (toString order.number) ]
      , Table.td [] [ text order.name ]
      , Table.td [ cellAttr (class "text-center") ] [ text totalItems ]
      , Table.td [ cellAttr (class "text-right") ] [ text totalPrice ]
      , Table.td [ cellAttr (class "text-center") ] [ text (statusString now order.status) ]
      , Table.td [ cellAttr (class "text-right") ] [
          Button.button
            [ Button.small, Button.primary, Button.onClick (SelectOrder order)]
            [ text "Details" ]
        ]
      ]


modalView : Date.Date -> Maybe Order -> Int -> Html Msg
modalView now order expected =
  case order of
    Nothing ->
      text ""
    Just order ->
      let
        title = "Order #" ++ (toString order.number) ++ " - " ++ order.name ++ " (" ++ order.telephone ++ ")"
        due = (toString expected) ++ " min"
      in
        Modal.config CloseModal
          |> Modal.large
          |> Modal.h5 [] [ text title ]
          |> Modal.body [ class "d-flex flex-row" ]
              [ div [ class "flex-grow-1" ]
                  [ Menu.invoiceView order.menu order.order ]
              , div [ class "divider"] []
              , div [ class "text-center" ]
                  [ p [ class "status"]
                      [ span [ class "head"] [ text "Expected: " ]
                      , span [] [ text due ]
                      ]
                  , p [] [ timeButton order -5
                         , timeButton order 5
                         ]
                  , p [ class "status"]
                      [ span [ class "head"] [ text "Status: " ]
                      , span [] [ text (statusString now order.status) ]
                      ]
                  , statusButton order "Accept" (Expected (addMinutes now expected))
                  , statusButton order "Ready" Ready
                  , statusButton order "Reject" Rejected
                  ]
              ]
          |> Modal.view Modal.shown


timeButton : Order -> Int -> Html Msg
timeButton order delta =
  let
    sign = if delta > 0 then "+" else ""
    label = sign ++ (toString delta) ++ "m"
  in
  Button.button
    [ Button.primary
    , Button.small
    , Button.attrs [ class "mx-1" ]
    , Button.onClick (ExpectedDelta delta)
    ]
    [ text label ]

statusButton : Order -> String -> OrderStatus -> Html Msg
statusButton order label state =
  p [] [ Button.button
          [ Button.primary, Button.onClick (SetStatus order state) ]
          [ text label ]
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


formatCreated : Date.Date -> Date.Date -> String
formatCreated now created =
  let
    (hh, mm, ss, ap) = timeBits created
    date =
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


statusString : Date.Date -> OrderStatus -> String
statusString now status =
  case status of
    Expected expected ->
      let
        minutes = (((Date.toTime expected) - (Date.toTime now))
          |> Time.inMinutes
          |> floor
          |> toString )
      in
        "Expected: " ++ minutes ++ "m"
    _ ->
      toString status

clock : Date.Date -> String
clock now =
  let
    (hh, mm, ss, ap) = timeBits now
  in
    hh ++ ":" ++ mm ++ ":" ++ ss ++ ap
