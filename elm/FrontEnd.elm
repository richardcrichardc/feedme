module FrontEnd exposing (..)

import Util.Loader as Loader
import Navigation
import Char
import Menu
import Scroll
import Window
import Task
import Http
import Util.Form as Form
import Util.ErrorDialog as ErrorDialog

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string, int)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)
import Json.Encode as Encode

import Html exposing (..)
import Html.Attributes exposing(id, class, src, style, href)

import Bootstrap.Navbar as Navbar
import Bootstrap.Button as Button

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
  let
    (initialNavbarState, initialNavbarCmd) = Navbar.initialState NavbarMsg
    maybeModel = decodeValue (decodeModel initialNavbarState) value
    maybeModelWithPage =
      case maybeModel of
        Ok model -> Ok { model | page = hashToPage location }
        Err err -> Err err
  in
    ( maybeModelWithPage
    , Cmd.batch
        [ Scroll.scrollHash location
        , initialNavbarCmd
        , Task.perform WindowSize Window.size
        ]
    )

-- MODEL

type alias Model =
  { name : String
  , address1 : String
  , address2 : String
  , town : String
  , phone : String
  , mapLocation : String
  , mapZoom : String
  , about : String
  , menuId : Int
  , menu : Menu.Menu
  , googleStaticMapsKey : String

  , order : Menu.Order
  , navbarState : Navbar.State
  , scrollPosition : Float
  , windowHeight : Float
  , page : Page
  , orderStatus : OrderStatus
  , errorDialog : ErrorDialog.Dialog Msg
  }

type Page = PageOne | PageTwo
type OrderStatus = Deciding | Ordering | Ordered

decodeModel : Navbar.State -> Decoder Model
decodeModel initialNavbarState =
    decode Model
      |> required "Name" string
      |> required "Address1" string
      |> required "Address2" string
      |> required "Town" string
      |> required "Phone" string
      |> required "MapLocation" string
      |> required "MapZoom" string
      |> required "About" string
      |> required "MenuId" int
      |> required "Menu" Menu.menuDecoder
      |> required "GoogleStaticMapsKey" string
      |> hardcoded [ {id=1, qty=1}, {id=2, qty=2}, {id=3, qty=3}]
      |> hardcoded initialNavbarState
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded PageOne
      |> hardcoded Deciding
      |> hardcoded Nothing

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Scroll.scrollPosition Scrolled
  , Navbar.subscriptions model.navbarState NavbarMsg
  , Window.resizes WindowSize
  ]

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | MenuMsg Menu.Msg
  | NavbarMsg Navbar.State
  | Scrolled Int
  | WindowSize Window.Size
  | PlaceOrder
  | PlaceOrderResponse (Result Http.Error String)
  | ToggleErrorDetails

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
      ({ model | page = hashToPage location }
      , Cmd.none
      )

    MenuMsg (Menu.Add item) ->
      ( { model | order = Menu.orderAdd item model.order }
      , Cmd.none
      )

    NavbarMsg state ->
      ( { model | navbarState = state }, Cmd.none )

    Scrolled scrollPosition ->
      ( { model | scrollPosition = toFloat scrollPosition }, Cmd.none )

    WindowSize windowSize ->
      ( { model | windowHeight = toFloat windowSize.height }, Cmd.none )

    PlaceOrder ->
      let
        body = Http.jsonBody (encodeOrder model.menuId model.order)
        request = Http.post "/placeOrder" body decodePostResponse
      in
        ({ model | orderStatus = Ordering }
        , Http.send PlaceOrderResponse request)

    PlaceOrderResponse (Ok _) ->
        ({ model | orderStatus = Ordered}, Cmd.none)

    PlaceOrderResponse (Err err) ->
        ({ model |
            errorDialog = ErrorDialog.dialog "Error" (Just ("Retry", PlaceOrder)) (Just (toString err, ToggleErrorDetails))}
        , Cmd.none)

    ToggleErrorDetails ->
      ({ model | errorDialog = ErrorDialog.toggleDetails model.errorDialog }
      , Cmd.none)


hashToPage : Navigation.Location -> Page
hashToPage location =
  case location.hash of
    "#order" -> PageTwo
    _ -> PageOne


encodeOrder : Int -> Menu.Order -> Value
encodeOrder menuId order =
  Encode.object
      [ ("MenuId", Encode.int menuId)
      , ("Order", Encode.list (List.map encodeOrderItem order))
      ]

encodeOrderItem : Menu.OrderItem -> Value
encodeOrderItem item =
    Encode.object
      [ ("Id", Encode.int item.id)
      , ("Qty", Encode.int item.qty)
      ]

decodePostResponse = string

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ ErrorDialog.view model.errorDialog
    , navbarView model
    , logoView model.name
    , menuOrderView model
    , locationView model
    , aboutView model.about
    , footer
    ]

navbarView : Model -> Html Msg
navbarView model =
  let
    startFade = 0.75 * model.windowHeight
    endFade = model.windowHeight
    opacity = max 0.0 (min 1.0 ((model.scrollPosition - startFade) / (endFade - startFade)))
  in
    if opacity > 0.0 then
      div [ style [("opacity", (toString opacity))]]
        [ Navbar.config NavbarMsg
            |> Navbar.withAnimation
            |> Navbar.fixTop
            |> Navbar.brand [ href "#"] [ text "Brand" ]
            |> Navbar.items
                [ Navbar.itemLink [ href "#menu" ] [ text "Menu" ]
                , Navbar.itemLink [ href "#order" ] [ text "Order"]
                , Navbar.itemLink [ href "#location" ] [ text "Location" ]
                , Navbar.itemLink [ href "#about" ] [ text "About" ]
                ]
            |> Navbar.view model.navbarState
        ]
      else
        text ""


logoView : String -> Html Msg
logoView name =
  let
    enspace = String.fromChar (Char.fromCode 8194)
    emdash = String.fromChar (Char.fromCode 8212)
  in
    div
      [ class "container logo-box d-flex flex-column justify-content-center" ]
      [ div [ ]
        [ img [ class "mx-auto d-block", src "/assets/food-e8350f.jpg" ] []
        , h1 [ class "text-center", style [("margin-top", "1em")] ] [ text name ]
        , p [ class "logo-box-nav"]
            [ a [ href "#menu" ] [ text "Menu"]
            , text enspace
            , a [ href "#order" ] [ text "Order"]
            , text (" " ++ emdash ++ " ")
            , a [ href "#location" ] [ text "Location"]
            , text enspace
            , a [ href "#about" ] [ text "About"]
            ]
        ]
      ]

menuOrderView : Model -> Html Msg
menuOrderView model =
  div [ id "menu", class "container section" ]
    [ div [ id "order" ]
        [ case model.page of
            PageOne -> menuView model
            PageTwo -> orderView model
        ]
    ]

menuView : Model -> Html Msg
menuView model =
  div [ class "menu" ]
    [ h2 [] [ text "Menu" ]
    , Html.map MenuMsg (Menu.menuView model.menu model.order)
    ]

orderView : Model -> Html Msg
orderView model =
  div [ class "order" ]
    [ div [ class "float-right order-now" ]
        [ Form.spinnerButton "Order Now" False (model.orderStatus == Ordering) PlaceOrder ]
    , h2 [] [ text "Your Order" ]
    , Html.map MenuMsg (Menu.invoiceView model.menu model.order)
    ]


locationView : Model -> Html Msg
locationView model =
  let
    mapUrl = "https://maps.googleapis.com/maps/api/staticmap"
             ++ "?markers=" ++ (Http.encodeUri model.mapLocation)
             ++ "&zoom=" ++ (Http.encodeUri model.mapZoom)
             ++ "&size=300x300&style=feature:poi.business|visibility:off&"
             ++ "key=" ++ (Http.encodeUri model.googleStaticMapsKey)
  in
    div [ class "container section" ]
    [ h2 [ id "location" ] [ text "Location" ]
    , img [ class "map mx-auto d-block", src mapUrl ] []
    , div [ class "d-flex justify-content-center"]
        [ dl []
            [ dt [] [ text "Phone" ]
            , dd [] [ text model.phone ]
            , dt [] [ text "Address" ]
            , dd [] ((strBr model.address1) ++ (strBr model.address2) ++ (strBr model.town))
            ]
        ]
    ]

strBr : String -> List (Html Msg)
strBr str =
  let
    trimmed = String.trim str
  in
    if String.isEmpty trimmed then
      []
    else
      [ text trimmed, br [] []]


aboutView : String -> Html Msg
aboutView about =
    div [ class "container section" ]
    ([ h2 [ id "about" ] [ text "About" ] ] ++ (text2html about))


text2html : String -> List (Html Msg)
text2html str =
  let
    paras = String.split "\n\n" str
    para2html = \ para ->
                           String.split "\n" para
                        |> List.map text
                        |> List.intersperse (br [] [])
                        |> p []
  in
    List.map para2html paras

footer : Html Msg
footer =
  p [ class "footer" ]
    [ text "Website by "
    , a [ href "#" ] [ text "feedme.nz" ]
    ]
