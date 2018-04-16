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
  }

type alias Row =
  { rowType : RowType
  , id : String
  , label : String
  , value : String
  }

type RowType = StringRow
             | TextRow

decodeModel : Decoder Model
decodeModel = Decode.map2 Model
    (field "What" string)
    (field "Rows" (list decodeRow))

decodeRow : Decoder Row
decodeRow =
  Decode.map4 Row
    (field "Type" decodeRowType)
    (field "Id" string)
    (field "Label" string)
    (field "Value" string)

decodeRowType : Decoder RowType
decodeRowType =
  string
    |> Decode.andThen (\str ->
        case str of
          "STRING" ->
            Decode.succeed StringRow
          "TEXT" ->
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
        , Form.form [] (List.map rowView model.rows)
        ]

rowView : Row -> Html Msg
rowView row =
    Form.row []
      [ Form.colLabel [ Col.sm2, Col.attrs [for row.id] ] [ text row.label]
      , Form.col [ Col.sm10 ]
        [ case row.rowType of
            StringRow -> Input.text [ Input.id row.id, Input.value row.value ]
            TextRow -> Textarea.textarea [ Textarea.id row.id, Textarea.value row.value ]
        , Form.help [] [ text (toString row.rowType) ]
        ]
      ]

