module MenuEditor exposing (..)

import Util.Loader as Loader
import Navigation
import Http

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, resolve)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (cols, rows, style)

import Json.Encode as Encode

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Row as Row
import Bootstrap.Grid.Col as Col
import Bootstrap.Alert as Alert
import Bootstrap.Form as Form
import Bootstrap.Button as Button

import Util.Form
import Util.ErrorDialog as ErrorDialog
import Menu

main =
  Loader.programWithFlags
    { decoder = decodeModel
    , view = view
    , update = update
    }

-- MODEL

type alias Model =
  { url: String
  , cancelUrl : String
  , savedUrl : String
  , json : String
  , error : String
  , menu : Maybe Menu.Menu
  , order : Menu.Order
  , saving : Bool
  , errorDialog : ErrorDialog.Dialog Msg
  }


decodeModel : Decoder Model
decodeModel =
  let
    toDecoder : String -> String -> String -> String -> Decoder Model
    toDecoder url cancelUrl savedUrl json =
      let
        (error, menu) =
          case Menu.decode json of
            Ok menu -> ("", Just menu)
            Err err -> (err, Nothing)
      in
        succeed (Model url cancelUrl savedUrl json error menu [] False Nothing)
  in
    decode toDecoder
      |> required "Url" string
      |> required "CancelUrl" string
      |> required "SavedUrl" string
      |> required "Json" string
      |> resolve


-- UPDATE

type Msg
  = Change String
  | Cancel
  | Save
  | SaveResponse (Result Http.Error String)
  | MenuMsg Menu.Msg
  | ToggleErrorDetails

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Change newJson ->
      let
        (newError, newMenu) =
          case Menu.decode newJson of
            Ok menu -> ("", Just menu)
            Err err -> (err, model.menu)
      in
        ({ model |
           json = newJson
           , error = newError
           , menu = newMenu
        }, Cmd.none)

    Cancel ->
      (model, Navigation.back 1)

    Save ->
      let
        body = Http.stringBody "application/json" model.json
        request = Http.post model.url body decodePostResponse
      in
        ({ model | saving = True }
        , Http.send SaveResponse request)

    SaveResponse (Ok _) ->
        (model, Navigation.load model.savedUrl)

    SaveResponse (Err err) ->
        ({ model |
            saving = True,
            errorDialog = ErrorDialog.dialog "Error" (Just ("Retry", Save)) (Just (toString err, ToggleErrorDetails))}
        , Cmd.none)

    MenuMsg menuMsg -> (model, Cmd.none)

    ToggleErrorDetails ->
      ({ model | errorDialog = ErrorDialog.toggleDetails model.errorDialog }
      , Cmd.none)


decodePostResponse = string


-- VIEW

view : Model -> Html Msg
view model =
  Grid.container []
    [ ErrorDialog.view model.errorDialog
    , h1 [] [ text "Edit Menu" ]
    , Grid.row []
      [ Grid.col [ Col.md ]
          [ rowcol [
              textarea
                [ cols 70
                , rows 15
                , style [ ("width", "100%") ]
                , onInput Change
                ]
                [ text model.json ]]
            , rowcol [ Util.Form.cancelSaveButtonView (model.error /= "") model.saving Cancel Save ]
            , rowcol [
                if model.error == "" then
                  text ""
                else
                  Alert.simpleDanger [] [ text model.error ]]
          ]
      , Grid.col [ Col.md ]
          [ Html.map MenuMsg (Menu.maybeMenuView model.menu model.order)
          ]
      ]
    ]

--RowCol : List (Html msg) -> List (Html msg)
rowcol x =
  Grid.row [] [ Grid.col [] x ]
