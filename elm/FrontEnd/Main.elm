module FrontEnd.Main exposing (..)

import Models.Menu as Menu
import Models.Restaurant as Restaurant

import Util.Loader as Loader
import Navigation
import Char
import Scroll
import Window
import Task
import Time
import Process
import Http
import Util.Form as Form
import Util.ErrorDialog as ErrorDialog
import Views.Layout as Layout

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string, int)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)
import Json.Encode as Encode

import Html exposing (..)
import Html.Attributes exposing(id, class, src, style, href, placeholder)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col
import Bootstrap.Alert as Alert

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
  { restaurant : Restaurant.Restaurant
  , menuId : Int
  , menu : Menu.Menu
  , googleStaticMapsKey : String

  , order : Menu.Order
  , confirmName : String
  , confirmPhone : String

  , scrollPosition : Float
  , menuTop : Float
  , menuHeight : Float
  , windowHeight : Float
  , page : Page
  , orderStatus : OrderStatus
  , errorDialog : ErrorDialog.Dialog Msg
  }

type Page = PageOne | PageTwo | PageThree
type OrderStatus = Deciding (Maybe String) | Ordering

decodeModel : Decoder Model
decodeModel =
    decode Model
      |> required "Restaurant" Restaurant.decode
      |> required "MenuID" int
      |> required "Menu" Menu.menuDecoder
      |> required "GoogleStaticMapsKey" string
      |> hardcoded [] -- [ {id=1, qty=1}, {id=2, qty=2}, {id=3, qty=3}]
      |> hardcoded ""
      |> hardcoded ""
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded 0.0
      |> hardcoded PageOne
      |> hardcoded (Deciding Nothing)
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
  | PlaceOrderResponse (Result Http.Error PostResponse)
  | ToggleErrorDetails
  | UpdateConfirmName String
  | UpdateConfirmPhone String

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
        body = Http.jsonBody (encodeOrder model.confirmName model.confirmPhone model.menuId model.order)
        request = Http.post "/placeOrder" body decodePostResponse
      in
        ({ model |
            orderStatus = Ordering,
            errorDialog = Nothing
          }
        , Http.send PlaceOrderResponse request)

    PlaceOrderResponse response ->
      case response of
        (Ok Okay) ->
          (model, Navigation.load ("/" ++ model.restaurant.slug ++ "/status"))

        (Ok (Error msg)) ->
          ({ model | orderStatus = Deciding (Just msg)}, Cmd.none)


        (Err err) ->
          ({ model |
              errorDialog = ErrorDialog.dialog "Error" (Just ("Retry", PlaceOrder)) (Just (toString err, ToggleErrorDetails))}
          , Cmd.none)

    ToggleErrorDetails ->
      ({ model | errorDialog = ErrorDialog.toggleDetails model.errorDialog }
      , Cmd.none)

    UpdateConfirmName name ->
      ({ model | confirmName = name}, Cmd.none)

    UpdateConfirmPhone phone ->
      ({ model | confirmPhone = phone}, Cmd.none)


hashToPage : Navigation.Location -> Page
hashToPage location =
  case location.hash of
    "#order" -> PageTwo
    "#confirm" -> PageThree
    _ -> PageOne


encodeOrder : String -> String -> Int -> Menu.Order -> Value
encodeOrder name phone menuId order =
  Encode.object
      [ ("Name", Encode.string name)
      , ("Telephone", Encode.string phone)
      , ("MenuId", Encode.int menuId)
      , ("Items", Encode.list (List.map encodeOrderItem order))
      ]

encodeOrderItem : Menu.OrderItem -> Value
encodeOrderItem item =
    Encode.object
      [ ("Id", Encode.int item.id)
      , ("Qty", Encode.int item.qty)
      ]

type PostResponse = Okay
                  | Error String


decodePostResponse : Decoder PostResponse
decodePostResponse =
  (Decode.field "Status" string)
    |> Decode.andThen (\str ->
      case str of
        "OK" -> Decode.succeed Okay
        "ERR" -> Decode.map Error (Decode.field "Error" string)
        _ -> Decode.fail ("Bad 'Status': " ++ str)
    )


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ ErrorDialog.view model.errorDialog
    , navbarView model
    , logoView model.restaurant.name
    , placeOrderView model
    , locationView model
    , aboutView model.restaurant.about
    , footer
    ]


navbarView : Model -> Html Msg
navbarView model =
  let
    opacity = 1.0 --navbarOpacity model
  in
    Layout.navbarView model.restaurant.name opacity
      <| case model.page of
          PageOne ->
            [ Button.linkButton [ Button.primary, Button.attrs [ href "#order" ] ] [ text "Review Order »" ] ]
          PageTwo ->
            [ Button.linkButton [ Button.primary, Button.attrs [ href "#menu", class "mr-2"] ] [ text "« Menu" ]
            , Button.linkButton [ Button.primary, Button.attrs [ href "#confirm" ] ] [ text "Confirm »" ]
            ]
          PageThree ->
            [ Button.linkButton [ Button.primary, Button.attrs [ href "#order" ] ] [ text "« Review Order" ] ]


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
    submitDisabled = String.isEmpty (String.trim model.confirmName)
                   || String.isEmpty (String.trim model.confirmPhone)
  in
    div []
      [ navbarView model
      , div [ class "container section confirm" ]
          [ h2 [] [ text "Confirm Order" ]
          , case model.orderStatus of
              Deciding (Just errorMsg) ->
                Alert.simpleDanger [] [ text errorMsg ]
              _ ->
                text ""
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
                  [ Input.text [ Input.value model.confirmName, Input.onInput UpdateConfirmName ] ]
              ]
            , Form.row []
              [ Form.colLabel [ Col.sm2 ] [ text "Telephone" ]
              , Form.col [ Col.sm10 ]
                  [ Input.text [ Input.value model.confirmPhone, Input.onInput UpdateConfirmPhone ] ]
              ]
            ]
          , p [] [ Form.spinnerButton "Order Now" submitDisabled (model.orderStatus == Ordering) PlaceOrder ]
          ]
      ]

locationView : Model -> Html Msg
locationView model =
  let
    restaurant = model.restaurant
    mapUrl = "https://maps.googleapis.com/maps/api/staticmap"
             ++ "?markers=" ++ (Http.encodeUri restaurant.mapLocation)
             ++ "&zoom=" ++ (Http.encodeUri restaurant.mapZoom)
             ++ "&size=300x300&style=feature:poi.business|visibility:off&"
             ++ "key=" ++ (Http.encodeUri model.googleStaticMapsKey)
  in
    div [ class "container section" ]
    [ h2 [ id "location" ] [ text "Location" ]
    , img [ class "map mx-auto d-block", src mapUrl ] []
    , div [ class "d-flex justify-content-center"]
        [ dl []
            [ dt [] [ text "Phone" ]
            , dd [] [ text restaurant.phone ]
            , dt [] [ text "Address" ]
            , dd [] ((strBr restaurant.address1) ++ (strBr restaurant.address2) ++ (strBr restaurant.town))
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
