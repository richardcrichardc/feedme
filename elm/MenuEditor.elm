module MenuEditor exposing (..)

import Navigation

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)

import Json.Encode as Encode

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Row as Row
import Bootstrap.Grid.Col as Col
import Bootstrap.Alert as Alert
import Bootstrap.Form as Form
import Bootstrap.Button as Button

import Rails
import Menu exposing (..)

main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

-- MODEL

type alias Model =
  { target : Rails.FormTarget
  , json : String
  , error : String
  , menu : Maybe Menu.Menu
  , order : Menu.Order
  }


type alias Fields = { json : Maybe String }

--type alias Flags =
--  { target : FormTarget
--  , fields :
--  }

init : Rails.FormFlags Fields -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
  let
    (initialJson, initialError, initialMenu) =
      case flags.fields.json of
        Just json ->
          case decode json of
            Ok menu -> (json, "", Just menu)
            Err err -> (json, err, Nothing)
        Nothing -> ("{}", "", Nothing)
  in
    ( { target = flags.target
      , json = initialJson
      , error = initialError
      , menu = initialMenu
      , order = []
      }
    , Cmd.none
    )


-- UPDATE

type Msg
  = Change String
  | Save
  | SaveResponse Rails.Msg
  | MenuMsg Menu.Msg
  | NewLocation Navigation.Location

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Change newJson ->
      let
        (newError, newMenu) =
          case decode newJson of
            Ok menu -> ("", Just menu)
            Err err -> (err, model.menu)
      in
        ({ model |
           json = newJson
           , error = newError
           , menu = newMenu
        }, Cmd.none)

    Save ->
      let
        payload = Encode.object
                  [ ("json", Encode.string model.json) ]
      in
        (model, Cmd.map SaveResponse (Rails.submitForm model.target "menu" payload))

    SaveResponse railsMsg ->
      case railsMsg of
        Rails.FormRedirect location -> ( model, Navigation.load location )
        Rails.FormError err -> ( { model | error = err }, Cmd.none )

    MenuMsg menuMsg -> (model, Cmd.none)

    NewLocation menuMsg -> (model, Cmd.none)



-- VIEW

view : Model -> Html Msg
view model =
  Grid.container []
    [ Grid.row []
      [ Grid.col [ Col.md ]
          [ rowcol [
              textarea
                [ cols 70
                , rows 15
                , style [ ("width", "100%") ]
                , onInput Change
                ]
                [ text model.json ]]
            , rowcol [ Button.button
                        [ Button.primary
                        , Button.disabled (model.error /= "")
                        , Button.onClick Save
                        ]
                        [ text "Save" ]
                      ]
            , rowcol [
                if model.error == "" then
                  text ""
                else
                  Alert.simpleDanger [] [ text model.error ]]
          ]
      , Grid.col [ Col.md ]
          [ Html.map MenuMsg (maybeMenuView model.menu model.order)
          ]
      ]
    ]

--RowCol : List (Html msg) -> List (Html msg)
rowcol x =
  Grid.row [] [ Grid.col [] x ]
