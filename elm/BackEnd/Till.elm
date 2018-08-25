module BackEnd.Till exposing (..)

import Util.Loader as Loader
import Html exposing (..)
import Html.Attributes exposing(class, src)
import Html.Events exposing(onClick)
import Navigation
import Json.Decode as Decode exposing (
  Value, Decoder,
  decodeValue, decodeString,
  field, andThen, fail, succeed, list, int, string)
import Json.Encode as Encode
import Views.Layout as Layout
import Models.Restaurant as Restaurant
import Models.Menu as Menu
import Models.OrderStatus as OrderStatus exposing (
  OrderStatus, StatusUpdate,
  dateDecoder, statusDecoder, statusUpdateDecoder)
import Json.Decode.Pipeline exposing (decode, required, hardcoded, custom)
import Util.Form exposing (spinner)
import Util.Sound as Sound
import Date
import Time exposing (every, second)
import Task
import Bootstrap.Table as Table exposing (cellAttr)
import Bootstrap.Button as Button
import Bootstrap.Modal as Modal
import Process
import Util.SSE as SSE
import Http
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
init flags location =
    ( decodeValue modelDecoder flags
    , Cmd.batch
        [ Task.perform Tick Time.now
        , SSE.createEventSource "/till/events"
        ]
    )

-- MODEL

type alias Model =
  { restaurant : Restaurant.Restaurant
  , orders : List Order
  , now : Time.Time
  , modalOrder : Maybe Order
  , expected : Int
  , muted : Bool
  , networkError : Bool
  }

type alias Order =
  { number : Int
  , name : String
  , telephone : String
  , menu : Menu.Menu
  , order : Menu.Order
  , created : Time.Time
  , status : OrderStatus
  }


modelDecoder : Decoder Model
modelDecoder =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> hardcoded []
      |> hardcoded 0
      |> hardcoded Nothing
      |> hardcoded 15
      |> hardcoded True
      |> hardcoded False

orderDecoder : Decoder Order
orderDecoder =
    decode Order
      |> required "Number" int
      |> required "Name" string
      |> required "Telephone" string
      |> required "MenuItems" Menu.menuDecoder
      |> required "Items" Menu.orderDecoder
      |> custom (field "CreatedAt" string |> andThen dateDecoder)
      |> custom statusDecoder


type Event
  = ResetEvent
  | NewOrderEvent Order
  | StatusUpdateEvent StatusUpdate

decodeEvent : String -> Result String Event
decodeEvent eventStr =
  case SSE.decodeEvent eventStr of
    Ok event ->
      let
        _ = Debug.log "Event" event
      in
        case event.event of
          "reset" ->
            Ok ResetEvent
          "order" ->
            case decodeValue orderDecoder event.data of
              Ok order ->
                Ok (NewOrderEvent order)
              Err err ->
                Err err
          "statusUpdate" ->
            case decodeValue statusUpdateDecoder event.data of
              Ok update ->
                Ok (StatusUpdateEvent update)
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


addMinutes : Time.Time -> Int -> Time.Time
addMinutes time minutes =
    time + (toFloat minutes * Time.minute)


updateOrderStatus : List Order -> StatusUpdate -> List Order
updateOrderStatus orders update =
  let
    updater order =
      if order.number == update.number then
        { order | status = update.status }
      else
        order
  in
    sortOrders (List.map updater orders)


sortOrders : List Order -> List Order
sortOrders orders =
  let
    orderComparison a b =
      OrderStatus.comparison a.status b.status
  in
    List.sortWith orderComparison orders


-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | SSEvent String
  | SelectOrder Order
  | CloseModal
  | SetStatus StatusUpdate
  | OrderStatusUpdateResponse StatusUpdate (Result Http.Error String)
  | ResendOrderStatusUpdate StatusUpdate
  | ExpectedDelta Int
  | ToggleMute


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      (model, Cmd.none)

    Tick now ->
      ({ model | now = now }, Cmd.none)

    SSEvent value ->
      case decodeEvent value of
        Ok ResetEvent ->
          ({ model | orders = [] }, Cmd.none)
        Ok (NewOrderEvent order) ->
          ({ model | orders = sortOrders (order :: model.orders) },
            if model.muted then Cmd.none else Sound.bell)
        Ok (StatusUpdateEvent update) ->
          ({ model | orders = sortOrders (updateOrderStatus model.orders update) }
          , Cmd.none)
        Err err ->
          let
            _ = Debug.log "Bad SSEvent: " (err ++ " Event: " ++ (toString value))
          in
            (model, Cmd.none)

    SelectOrder order ->
      ({ model | modalOrder = Just order }, Cmd.none)

    CloseModal ->
      ({ model | modalOrder = Nothing }, Cmd.none)

    SetStatus update ->
      ({ model |
          orders = updateOrderStatus model.orders update,
          modalOrder = Nothing
       }
      , sendOrderStatusUpdate update)

    OrderStatusUpdateResponse update result ->
      case (Debug.log "response" result) of
        (Ok _) ->
          ({ model | networkError = False }, Cmd.none)

        (Err err) ->
          ({ model | networkError = True }
          , Process.sleep (5 * Time.second)
              |> Task.perform (\_ -> ResendOrderStatusUpdate update)
          )

    ResendOrderStatusUpdate update ->
     (model , sendOrderStatusUpdate update)

    ExpectedDelta delta ->
      ({ model | expected = model.expected + delta }, Cmd.none)

    ToggleMute ->
      ({ model | muted = not model.muted }, Cmd.none)


sendOrderStatusUpdate : StatusUpdate -> Cmd Msg
sendOrderStatusUpdate update =
  let
    body = Http.jsonBody
      <| Encode.object
          [ ("Number", Encode.int update.number)
          , ("Status", Encode.string (toString update.status))
          ]
    request = Http.post "/till/updateOrder" body string
  in
    Http.send (OrderStatusUpdateResponse update) request


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbarView model
    , modalView model.now model.expected model.modalOrder
    , div [ class "container section" ]
      [ h2 [] [ text "Orders " ]
      , ordersView model.now model.expected model.orders
      ]
    , Sound.bellView
    ]


navbarView : Model -> Html Msg
navbarView model =
  let
    title =
      model.restaurant.name ++ " - Till"
    muteIcon =
      if model.muted then
        "/assets/sound-off-429b15.svg"
      else
        "/assets/sound-on-2769c5.svg"
    networkError =
      if model.networkError then
        "Network error"
      else
        ""

  in
    Layout.navbarView title 1.0
      [ span [] [ text networkError ]
      , img [ class "mute-button", src muteIcon, onClick ToggleMute ] []
      , span [ class "clock" ] [ text (clock model.now) ]
      ]


ordersView : Time.Time -> Int -> List Order -> Html Msg
ordersView now expected orders =
  Table.table
    { options = [ Table.attr (class "table-fixed") ]
    , thead =
        Table.simpleThead
          [ Table.th [ cellAttr (class "text-center") ] [ text "#" ]
          , Table.th [] [ text "Name" ]
          , Table.th [ cellAttr (class "text-center") ] [ text "Items" ]
          , Table.th [ cellAttr (class "text-right") ] [ text "Total" ]
          , Table.th [ cellAttr (class "text-center") ] [ text "Status" ]
          , Table.th [] [ text "" ]
          ]
    , tbody =
        Table.tbody [] (List.map (ordersLineView now expected) orders)
    }

ordersLineView : Time.Time -> Int -> Order -> Table.Row Msg
ordersLineView now expected order =
  let
    (totalItems, totalPrice) = Menu.orderTotals order.menu order.order
  in
    Table.tr []
      [ Table.td [ cellAttr (class "text-center") ] [ text (toString order.number) ]
      , Table.td [] [ text order.name ]
      , Table.td [ cellAttr (class "text-center") ] [ text totalItems ]
      , Table.td [ cellAttr (class "text-right") ] [ text totalPrice ]
      , Table.td [ cellAttr (class "text-center") ] [ text (statusString now order.status) ]
      , Table.td [ cellAttr (class "text-right") ]
          [ mostLikelyButton now expected order
          , Button.button
              [ Button.small, Button.primary, Button.onClick (SelectOrder order)]
              [ text "Details" ]
          ]
      ]


modalView : Time.Time -> Int -> Maybe Order -> Html Msg
modalView now expected order =
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
                  , statusButton order "Accept" (OrderStatus.Expected (addMinutes now expected))
                  , statusButton order "Ready" OrderStatus.Ready
                  , statusButton order "Picked Up" OrderStatus.PickedUp
                  , statusButton order "Reject" OrderStatus.Rejected
                  ]
              ]
          |> Modal.view Modal.shown


mostLikelyButton : Time.Time -> Int -> Order -> Html Msg
mostLikelyButton now expected order =
  let
    button order label state =
      Button.button
        [ Button.primary
        , Button.small
        , Button.attrs [ class "mx-1" ]
        , Button.onClick (SetStatus (StatusUpdate order.number state)) ]
        [ text label ]
  in
    case order.status of
      OrderStatus.New _ ->
        text ""
      OrderStatus.Expected _ ->
        button order "Ready" OrderStatus.Ready
      OrderStatus.Ready ->
        button order "Picked Up" OrderStatus.PickedUp
      OrderStatus.PickedUp ->
        text ""
      OrderStatus.Rejected ->
        text ""


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
  p []
    [ Button.button
        [ Button.primary, Button.onClick (SetStatus (StatusUpdate order.number state)) ]
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


statusString : Time.Time -> OrderStatus -> String
statusString now status =
  case status of
    OrderStatus.New _ ->
      "New"
    OrderStatus.Expected expected ->
      let
        minutes = ((expected - now)
          |> Time.inMinutes
          |> floor
          |> toString )
      in
        "Expected: " ++ minutes ++ "m"
    OrderStatus.PickedUp ->
      "Picked Up"
    _ ->
      toString status

clock : Time.Time -> String
clock now =
  let
    (hh, mm, ss, ap) = timeBits (Date.fromTime now)
  in
    hh ++ ":" ++ mm ++ ":" ++ ss ++ ap
