module Router exposing (main)

import Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode


main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

init : Decode.Value -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
  (route location
  , Cmd.none)

-- MODEL

type alias Model =
  { path : String
  , page : Page
  }

type Page
  = Home
  | Fe
  | Fi
  | Fo
  | NotFound

route loc =
  { path = loc.pathname ++ loc.search ++ loc.hash
  , page =
      case loc.pathname of
        "/admin/router"
          -> Home
        "/admin/router/fe"
          -> Fe
        "/admin/router/fi"
          -> Fi
        "/admin/router/fo"
          -> Fo
        _
          -> NotFound
    }

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Go String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewLocation loc ->
      ( route loc
      , Cmd.none )
    Go loc ->
      ( model
      , Navigation.newUrl loc )

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ h1 [] [ text "Router" ]
    , p [] [ text (toString model) ]
    , ul []
      [ li [] [ link "/admin/router" ]
      , li [] [ link "/admin/router/fe" ]
      , li [] [ link "/admin/router/fi" ]
      , li [] [ link "/admin/router/fo" ]
      ]
    ]


onPreventDefaultClick : msg -> Attribute msg
onPreventDefaultClick message =
    onWithOptions
        "click"
        { defaultOptions | preventDefault = True }
        (Decode.succeed message)

link url = a [ href url, onPreventDefaultClick (Go url) ] [ text url ]
