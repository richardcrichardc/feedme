module EditForm exposing (..)

import Navigation
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, dict)
import Html exposing (..)
import Html.Attributes exposing (for)
import Dict

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Button as Button
import Bootstrap.Utilities.Spacing as Spacing

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

type Row = StringRow BasicRowData
         | TextRow BasicRowData
         | Group String (List Row)

type alias BasicRowData =
  { id : String
  , label : String
  , value : String
  }

decodeModel : Decoder Model
decodeModel = Decode.map2 Model
    (field "What" string)
    (field "Rows" (list decodeRow))

decodeRow : Decoder Row
decodeRow =
  (field "Type" string)
    |> Decode.andThen (\str ->
        case str of
          "STRING" ->
            Decode.map StringRow decodeBasicRowData
          "TEXT" ->
            Decode.map TextRow decodeBasicRowData
          "GROUP" ->
            Decode.map2 Group
              (field "Label" string)
              (field "Rows" (list decodeRow))
          somethingElse ->
            Decode.fail <| "Unknown type: " ++ somethingElse
    )

decodeBasicRowData : Decoder BasicRowData
decodeBasicRowData =
  Decode.map3 BasicRowData
    (field "Id" string)
    (field "Label" string)
    (field "Value" string)


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
        , Form.form [] ((List.map rowView model.rows) ++ [(buttonView model)])
        ]

leftSize = Col.sm3
rightSize = Col.sm9

rowView : Row -> Html Msg
rowView row =
    case row of
      StringRow rowData ->
        rowRow (rowHeadView rowData) (stringRowView rowData) rowData
      TextRow rowData ->
        rowRow (rowHeadView rowData) (textRowView rowData) rowData
      Group label rows ->
        Grid.row [ Row.attrs [ Spacing.mb4 ]]
          [ Grid.col [ Col.sm12 ] (List.map rowView rows) ]

rowRow left right row =
  Form.row []
    [ left
    , Form.col [ rightSize ]
      [ right
      --, Form.help [] [ text (toString row) ]
      ]
    ]

rowHeadView data = Form.colLabel [ leftSize, Col.attrs [for data.id] ] [ text data.label]
stringRowView data = Input.text [ Input.id data.id, Input.value data.value ]
textRowView data = Textarea.textarea [ Textarea.id data.id, Textarea.value data.value ]

buttonView : Model -> Html Msg
buttonView model =
  Form.row []
    [ Form.col [ leftSize ] []
    , Form.col [ rightSize ]
      [ Button.button [ Button.primary ] [ text "Cancel" ]
      , Button.button [ Button.primary, Button.attrs [ Spacing.ml1 ]] [ text "Save" ]
      ]
    ]


