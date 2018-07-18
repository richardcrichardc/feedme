module FrontEnd exposing (..)

import Util.Loader as Loader
import Navigation
import Char
import Menu
import Scroll
import Window
import Task
import Time
import Process
import Http
import Util.Form as Form
import Util.ErrorDialog as ErrorDialog

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string, int)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)
import Json.Encode as Encode

import Html exposing (..)
import Html.Attributes exposing(id, class, src, style, href, placeholder)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col

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
    maybeModel = decodeValue decodeModel value
    maybeModelWithPage =
      case maybeModel of
        Ok model -> Ok { model | page = hashToPage location }
        Err err -> Err err
  in
    ( maybeModelWithPage
    , Cmd.batch
        [ Scroll.scrollHash location
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
  , scrollPosition : Float
  , menuTop : Float
  , menuHeight : Float
  , windowHeight : Float
  , page : Page
  , orderStatus : OrderStatus
  , errorDialog : ErrorDialog.Dialog Msg
  }

type Page = PageOne | PageTwo | PageThree
type OrderStatus = Deciding | Ordering | Ordered

decodeModel : Decoder Model
decodeModel =
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
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded PageOne
      |> hardcoded Deciding
      |> hardcoded Nothing

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Scroll.scrollPosition Scrolled
  , Window.resizes WindowSize
  ]

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | MenuMsg Menu.Msg
  | Scrolled (Int, Int, Int)
  | ScrollMenu
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

    ScrollMenu ->
      ( model, Scroll.scrollIntoView "menu" )

    MenuMsg (Menu.Add item) ->
      ( { model | order = Menu.orderAdd item model.order }
      , Cmd.none
      )

    Scrolled (scrollPosition, menuTop, menuHeight) ->
      ( { model |
          scrollPosition = toFloat scrollPosition,
          menuTop = toFloat menuTop,
          menuHeight = toFloat menuHeight
      }, Cmd.none )

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
    "#confirm" -> PageThree
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
    , placeOrderView model
    , locationView model
    , aboutView model.about
    , footer
    ]


navbarView : Model -> Html Msg
navbarView model =
  let
    opacity = navbarOpacity model
  in
    if opacity > 0.0 then
      div [ class "bg-light fixed-top", style [("opacity", (toString opacity)) ] ]
        [ div [ class "container px-3 py-2 text-right" ]
            <| case model.page of
                PageOne ->
                  [ Button.linkButton [ Button.primary, Button.attrs [ href "#order" ] ] [ text "Review Order »" ] ]
                PageTwo ->
                  [ Button.linkButton [ Button.primary, Button.attrs [ href "#menu", class "mr-2"] ] [ text "« Menu" ]
                  , Button.linkButton [ Button.primary, Button.attrs [ href "#confirm" ] ] [ text "Confirm »" ]
                  ]
                PageThree ->
                  [ Button.linkButton [ Button.primary, Button.attrs [ href "#order" ] ] [ text "« Review Order" ] ]

          ]
        else
          text ""


navbarOpacity : Model -> Float
navbarOpacity model =
  let
    fadeDistance = 0.25 * model.windowHeight
    endFadeIn = model.menuTop
    startFadeIn = endFadeIn - fadeDistance
    startFadeOut = model.menuTop + model.menuHeight
    endFadeOut = startFadeOut + fadeDistance
    fadeMiddle = endFadeIn + ((startFadeOut - endFadeIn) / 2)
    unboundOpacity = if model.scrollPosition < fadeMiddle then
                (model.scrollPosition - startFadeIn) / (endFadeIn - startFadeIn)
              else
                (model.scrollPosition - startFadeOut) / (startFadeOut - endFadeOut)
  in
    max 0.0 (min 1.0 unboundOpacity)


logoView : String -> Html Msg
logoView name =
  let
    enspace = String.fromChar (Char.fromCode 8194)
  in
    div
      [ class "container logo-box d-flex flex-column justify-content-center" ]
      [ div [ ]
        [ img [ class "mx-auto d-block", src "/assets/food-e8350f.jpg" ] []
        , h1 [ class "text-center", style [("margin-top", "1em")] ] [ text name ]
        , p [ class "logo-box-nav"]
            [ a [ href "#menu" ] [ text "Menu"]
            , text enspace
            , a [ href "#location" ] [ text "Location"]
            , text enspace
            , a [ href "#about" ] [ text "About"]
            ]
        ]
      ]


placeOrderView : Model -> Html Msg
placeOrderView model =
  div [ id "menu" ]
    [ div [ id "order" ]
      [ div [ id "confirm" ]
        [
          case model.page of
              PageOne -> menuView model
              PageTwo -> orderView model
              PageThree -> confirmView model
    ]]]


menuView : Model -> Html Msg
menuView model =
  div [ class "container section menu" ]
    [ h2 [] [ text "Menu" ]
    , Html.map MenuMsg (Menu.menuView model.menu model.order)
    ]


orderView : Model -> Html Msg
orderView model =
  div []
    [ navbarView model
    , div [ class "container section order" ]
      --[ div [ class "float-right order-now" ]
      --    [ Form.spinnerButton "Order Now" False (model.orderStatus == Ordering) PlaceOrder ]
      [ h2 [] [ text "Review Order" ]
      , Html.map MenuMsg (Menu.invoiceView model.menu model.order)
      ]
    ]

confirmView : Model -> Html Msg
confirmView model =
  let
    (totalItems, totalPrice) = Menu.orderTotals model.menu model.order
  in
    div []
      [ navbarView model
      , div [ class "container section confirm" ]
          [ h2 [] [ text "Confirm Order" ]
          , p [] [ text "Your order contains "
                 , strong [] [ text totalItems ]
                 , text " items and has total of "
                 , strong [] [ text totalPrice ]
                 , text "."
                 ]
          , Form.form []
            [ Form.row []
              [ Form.colLabel [ Col.sm2 ] [ text "Name" ]
              , Form.col [ Col.sm10 ]
                  [ Input.text [] ]
              ]
            , Form.row []
              [ Form.colLabel [ Col.sm2 ] [ text "Telephone" ]
              , Form.col [ Col.sm10 ]
                  [ Input.text [] ]
              ]
            ]
          , p [] [ Form.spinnerButton "Order Now" False (model.orderStatus == Ordering) PlaceOrder ]
          ]
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
