module MenuEditor exposing (..)

import Loader
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

import Menu

main =
  Loader.programWithFlagsDecoder
    { flagDecoder = decodeModel
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
        succeed (Model url cancelUrl savedUrl json error menu [])
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
  | Save
  | SaveResponse (Result Http.Error String)
  | MenuMsg Menu.Msg

update : Msg -> Model -> Loader.Error Msg -> (Model, Loader.Error Msg, Cmd Msg)
update msg model loaderError =
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
        }, loaderError, Cmd.none)

    Save ->
      let
        body = Http.stringBody "application/json" model.json
        request = Http.post model.url body decodePostResponse
      in
        (model, loaderError, Http.send SaveResponse request)

    SaveResponse (Ok dummy) ->
        (model, loaderError, Navigation.load model.savedUrl)

    SaveResponse (Err err) ->
        (model, Loader.PageError "Error" "Retry" Save (Just (toString err)), Cmd.none)

    MenuMsg menuMsg -> (model, loaderError, Cmd.none)


decodePostResponse = string


-- VIEW

view : Model -> Html Msg
view model =
  Grid.container []
    [ h1 [] [ text "Edit Menu" ]
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
          [ Html.map MenuMsg (Menu.maybeMenuView model.menu model.order)
          ]
      ]
    ]

--RowCol : List (Html msg) -> List (Html msg)
rowcol x =
  Grid.row [] [ Grid.col [] x ]
