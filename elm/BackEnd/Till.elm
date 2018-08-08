module BackEnd.Till exposing (..)

import Util.Loader as Loader
import Html exposing (..)
import Html.Attributes exposing(class)
import Navigation
import Json.Decode as Decode exposing (Value, Decoder, decodeValue, field, andThen, fail, succeed, list, int, string)
import Views.Layout as Layout
import Models.Restaurant as Restaurant
import Models.Menu as Menu
import Json.Decode.Pipeline exposing (decode, required, hardcoded, custom)
import Util.Form exposing (spinner)
import Date
import Time exposing (every, second)
import Task
import Bootstrap.Table as Table

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
        [ Task.perform Toc Date.now
        ]
    )

-- MODEL

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


decodeModel : Decoder Model
decodeModel =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> required "Orders" (list decodeOrder)
      |> hardcoded Nothing

decodeOrder : Decoder Order
decodeOrder =
    decode Order
      |> required "Number" int
      |> required "Name" string
      |> required "Telephone" string
      |> required "MenuID" int
      |> required "Items" Menu.orderDecoder
      |> custom (field "CreatedAt" string |> andThen decodeDate)


decodeDate : String -> Decoder Date.Date
decodeDate dateString =
  case Date.fromString dateString of
    Ok date -> succeed date
    Err err -> fail err


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ every second Tick
  ]

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Tick Time.Time
  | Toc Date.Date

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      (model, Cmd.none)
    Tick _ ->
      (model, Task.perform Toc Date.now )
    Toc now ->
      ({ model | now = Just now }, Cmd.none)



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
