module PlaceOrder exposing (..)

import Navigation
import Char
import Menu
import Rails
import Scroll

import Html exposing (..)
import Html.Attributes exposing(id, class, src, style, href)

import Bootstrap.Navbar as Navbar

main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

-- MODEL

type alias Model =
  { target : Rails.FormTarget
  , menu_id : Int
  , menu : Menu.Menu
  , order : Menu.Order
  , navbarState : Navbar.State
  , scrollPosition : Int
  }

type alias FlagFields =
  { menu_id : Int
  , menu : Menu.Menu
  }

init : Rails.FormFlags FlagFields -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
  let
    (initialNavbarState, initialNavbarCmd) = Navbar.initialState NavbarMsg
  in
    ( { target = flags.target
      , menu_id = flags.fields.menu_id
      , menu = flags.fields.menu
      , order = []
      , navbarState = initialNavbarState
      , scrollPosition = 0
      }
    , Cmd.batch
        [ Scroll.scrollHash location
        , initialNavbarCmd
        ]
    )

subscriptions : Model -> Sub Msg
subscriptions model =
  Scroll.scrollPosition Scrolled


-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | MenuMsg Menu.Msg
  | NavbarMsg Navbar.State
  | Scrolled Int

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation location ->
        (model, Scroll.scrollHash location)

    MenuMsg (Menu.Add item) ->
      ( { model | order = Menu.orderAdd item model.order }
      , Cmd.none
      )

    NavbarMsg state ->
      ( { model | navbarState = state }, Cmd.none )

    Scrolled scrollPosition ->
      ( { model | scrollPosition = scrollPosition }, Cmd.none )

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ navbarView model.navbarState model.scrollPosition
    , logoView model.menu.title
    , div [ id "menu", class "container menu section" ]
      [ h2 [] [ text "Menu" ]
      , Html.map MenuMsg (Menu.menuView model.menu model.order)
      ]
    , locationView
    , aboutView
    , footer
    ]

navbarView : Navbar.State -> Int -> Html Msg
navbarView state scrollPosition =
  let
    scrollPositionFloat = toFloat scrollPosition
    threshold = 100.0
    opacity = if scrollPositionFloat > threshold then
                0.0
              else
                1.0 - (scrollPositionFloat / threshold)
  in
    if opacity > 0.0 then
      div [ style [("opacity", (toString opacity))]]
        [ Navbar.config NavbarMsg
            |> Navbar.withAnimation
            |> Navbar.fixTop
            |> Navbar.brand [ href "#"] [ text "Brand"]
            |> Navbar.items
                [ Navbar.itemLink [ href "#menu" ] [ text "Menu"]
                , Navbar.itemLink [ href "#location" ] [ text "Location"]
                , Navbar.itemLink [ href "#about" ] [ text "About"]
                ]
            |> Navbar.view state
        ]
      else
        text ""

logoView : String -> Html Msg
logoView title =
  let
    enspace = String.fromChar (Char.fromCode 8194)
  in
    div
      [ class "container logo-box d-flex flex-column justify-content-center" ]
      [ div [ ]
        [ img [ class "mx-auto d-block", src "/assets/food-e8350f.jpg" ] []
        , h1 [ class "text-center", style [("margin-top", "1em")] ] [ text title ]
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

aboutView : Html Msg
aboutView =
  div [ class "container section" ]
  [ h2 [ id "about" ] [ text "About" ]
  , p [] [ text "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In ultricies euismod elit, a aliquam ex sodales ut." ]
  , p [] [ text "Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Integer consequat turpis sed sem viverra pellentesque. Quisque faucibus leo turpis, vel venenatis elit aliquet sit amet. Nullam at leo ut lacus convallis aliquet vitae sit amet ante. Aenean eu laoreet arcu, ut convallis purus." ]
  , p [] [ text "Nulla facilisi. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nullam auctor ac mauris ac pellentesque." ]
    ]

footer : Html Msg
footer =
  p [ class "footer" ]
    [ text "Website by "
    , a [ href "#" ] [ text "feedme.nz" ]
    ]
