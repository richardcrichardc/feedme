module EditForm exposing (..)

import Navigation
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, dict)
import Html exposing (..)
import Html.Attributes exposing (for)
import Dict

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea

import Scroll

main =
  Navigation.programWithFlags
    NewLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

init : Value -> Navigation.Location -> (ResultModel, Cmd Msg)
init flags location =
  ( decodeValue decodeModel flags
  , Scroll.scrollHash location
  )

-- MODEL

type alias ResultModel = Result String Model

type alias Data = Dict.Dict String String

type alias Model =
  { what : String
  , rows : List Row
  , data : Data
  }

type alias Row =
  { id : String
  , label : String
  , rowType : RowType
  }

type RowType = StringRow
             | TextRow

decodeModel : Decoder Model
decodeModel = Decode.map3 Model
    (field "What" string)
    (field "Rows" (list decodeRow))
    (field "Data" (dict string))

decodeRow : Decoder Row
decodeRow =
  Decode.map3 Row
    (field "Id" string)
    (field "Label" string)
    (field "Type" decodeRowType)

decodeRowType : Decoder RowType
decodeRowType =
  string
    |> Decode.andThen (\str ->
        case str of
          "string" ->
            Decode.succeed StringRow
          "text" ->
            Decode.succeed TextRow
          somethingElse ->
            Decode.fail <| "Unknown type: " ++ somethingElse
    )


-- UPDATE

type Msg
  = NewLocation Navigation.Location

update : Msg -> ResultModel -> (ResultModel, Cmd Msg)
update msg model =
  case msg of
    NewLocation menuMsg -> (model, Cmd.none)

-- VIEW

view : ResultModel -> Html Msg
view maybeModel =
  case maybeModel of
    Err msg ->
      div [] [ text  ("Load error: " ++ msg) ]
    Ok model ->
      Grid.container []
        [ h1 [] [ text ("EditForm: " ++ model.what) ]
        , Form.form [] (List.map (rowView model.data) model.rows)
        ]

rowView : Data -> Row -> Html Msg
rowView data row =
  let
    value = case Dict.get row.id data of
      Just value -> value
      Nothing -> "***MISSING DATA FIELD***"
  in
    Form.row []
      [ Form.colLabel [ Col.sm2, Col.attrs [for row.id] ] [ text row.label]
      , Form.col [ Col.sm10 ]
        [ case row.rowType of
            StringRow -> Input.text [ Input.id row.id, Input.value value ]
            TextRow -> Textarea.textarea [ Textarea.id row.id, Textarea.value value ]
        , Form.help [] [ text (toString row.rowType) ]
        ]
      ]

