module PlaceOrder exposing (..)

import Util.Loader as Loader
import Navigation
import Char
import Menu
import Scroll
import Window
import Task

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)

import Html exposing (..)
import Html.Attributes exposing(id, class, src, style, href)

import Bootstrap.Navbar as Navbar

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
  in
    (decodeValue (decodeModel initialNavbarState) value
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
  , menu : Menu.Menu
  , order : Menu.Order

  , navbarState : Navbar.State
  , scrollPosition : Float
  , windowHeight : Float
  }


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
      |> required "Menu" Menu.menuDecoder
      |> hardcoded []
      |> hardcoded initialNavbarState
      |> hardcoded 0.0
      |> hardcoded 0.0

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

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
        (model, Cmd.none)

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


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbarView model
    , logoView model.name
    , div [ id "menu", class "container menu section" ]
      [ h2 [] [ text "Menu" ]
      , Html.map MenuMsg (Menu.menuView model.menu model.order)
      ]
    , locationView
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

locationView : Html Msg
locationView =
  div [ class "container section" ]
  [ h2 [ id "location" ] [ text "Location" ]
  , img [ class "map mx-auto d-block", src "https://maps.googleapis.com/maps/api/staticmap?markers=foodtastic,Whanganui&zoom=17&size=300x300&style=feature:poi.business|visibility:off&key=AIzaSyDBuq2YPG4anbgWG5K-IgayWR1dG9fSIFg" ] []
  , p [] [ text "Majestic Square, Whanganui" ]
  ]

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
