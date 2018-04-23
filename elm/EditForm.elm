module EditForm exposing (..)

import Navigation
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, dict, bool)
import Json.Encode as Encode
import Html exposing (..)
import Html.Attributes
import Html.Events
import Dict
import Http

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
  let
    model = decodeValue decodeModel flags
  in
    ( case model of
        Ok model ->
          Ok { model | url = location.href }
        Err err -> Err err
    , Scroll.scrollHash location )

-- MODEL

type alias ResultModel = Result String Model

type alias Model =
  { url: String
  , what : String
  , rows : List Row
  , fields : Fields
  }

type Row = StringRow BasicRowData
         | TextRow BasicRowData
         | Group String (List Row)

type alias BasicRowData =
  { id : String
  , label : String
  }

type alias Fields = Dict.Dict String Field

type alias Field =
  { pristine : Bool
  , value : String
  , errors : List String
  }

decodeModel : Decoder Model
decodeModel = Decode.map4 Model
    (Decode.succeed "")
    (field "What" string)
    (field "Rows" (list decodeRow))
    (field "Data" (dict decodeField))

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
  Decode.map2 BasicRowData
    (field "Id" string)
    (field "Label" string)


decodeField : Decoder Field
decodeField =
  string
    |> Decode.andThen (\value ->
        Decode.succeed (Field False value [])
    )

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | Save
  | Cancel
  | UpdateField String String
  | BlurField
  | Validation (Result Http.Error String)

update : Msg -> ResultModel -> (ResultModel, Cmd Msg)
update msg resultModel =
  case resultModel of
    Err x -> (resultModel, Cmd.none)
    Ok model ->
      case msg of
        NewLocation menuMsg -> (Ok model, Cmd.none)
        Cancel -> (Ok model, Cmd.none)
        Save -> (Ok model, Cmd.none)

        UpdateField name newValue ->
          (Ok { model
              | fields = Dict.update name (updateFieldValue newValue) model.fields
              }, Cmd.none)

        BlurField -> (Ok model, post model.url "validate" model.fields)

        Validation (Ok s) -> (Ok model, Cmd.none)
        Validation (Err e) -> (Ok model, Cmd.none)

updateFieldValue : String -> Maybe Field -> Maybe Field
updateFieldValue newValue field =
  case field of
    Just field ->
      Just { field
           | pristine = False
           , value = newValue
           }
    Nothing -> Nothing


-- HTTP

post : String -> String -> Fields -> Cmd Msg
post url action fields =
  let
    fieldValue = \(id, field) -> (id, Encode.string field.value)
    fieldValues = \fields -> List.map fieldValue (Dict.toList fields)
    body = Http.jsonBody
            <| Encode.object
                  [ ("Action", Encode.string action)
                  , ("Fields", Encode.object (fieldValues fields))
                  ]
  in
    Http.send Validation <|
      Http.post url body string


-- VIEW

view : ResultModel -> Html Msg
view maybeModel =
  case maybeModel of
    Err msg ->
      div [] [ text  ("Load error: " ++ msg) ]
    Ok model ->
      Grid.container []
        [ h1 [] [ text ("EditForm: " ++ model.what) ]
        , p [] [ text("Url: " ++ model.url) ]
        , Form.form [] ((List.map (rowView model) model.rows) ++ [(buttonView model)])
        , pre [] [ text (toString model.fields) ]
        ]

leftSize = Col.sm3
rightSize = Col.sm9

rowView : Model -> Row -> Html Msg
rowView model row =
  case row of
    StringRow rowData ->
      rowRow (rowHeadView rowData) (stringRowView rowData model.fields) rowData
    TextRow rowData ->
      rowRow (rowHeadView rowData) (textRowView rowData model.fields) rowData
    Group label rows ->
      Grid.row [ Row.attrs [ Spacing.mb4 ]]
        [ Grid.col [ Col.sm12 ] (List.map (rowView model) rows) ]

rowRow left right row =
  Form.row []
    [ left
    , Form.col [ rightSize ]
      [ right
      --, Form.help [] [ text (toString row) ]
      ]
    ]

rowHeadView : BasicRowData -> Form.Col Msg
rowHeadView data = Form.colLabel [ leftSize, Col.attrs [Html.Attributes.for data.id] ] [ text data.label]

stringRowView : BasicRowData -> Fields -> Html Msg
stringRowView data fields =
  Input.text
    [ Input.id data.id
    , Input.onInput (UpdateField data.id)
    , Input.attrs [ Html.Events.onBlur BlurField ]
    , Input.value (getFieldValue fields data.id)
    ]

textRowView : BasicRowData -> Fields -> Html Msg
textRowView data fields =
  Textarea.textarea
    [ Textarea.id data.id
    , Textarea.onInput (UpdateField data.id)
    , Textarea.attrs [ Html.Events.onBlur BlurField ]
    , Textarea.value (getFieldValue fields data.id)
    ]

getFieldValue : Fields -> String -> String
getFieldValue fields id =
  case Dict.get id fields of
    Just field -> field.value
    Nothing -> "MISSING"


buttonView : Model -> Html Msg
buttonView model =
  Form.row []
    [ Form.col [ leftSize ] []
    , Form.col [ rightSize ]
      [ Button.button [ Button.primary, Button.onClick Cancel ] [ text "Cancel" ]
      , Button.button [ Button.primary, Button.attrs [ Spacing.ml1 ], Button.onClick Save ] [ text "Save" ]
      ]
    ]


