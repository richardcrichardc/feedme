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
import Bootstrap.Alert as Alert

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
  , error : Maybe String
  , fieldErrors : Dict.Dict String Errors -- TODO move into fields.errors
  }

type Row = StringRow BasicRowData
         | TextRow BasicRowData
         | Group String (List Row)

type alias BasicRowData =
  { id : String
  , label : String
  , help : String
  }

type alias Fields = Dict.Dict String Field

type alias Field =
  { pristine : Bool
  , value : String
  , errors : List String
  }

type alias Errors = List String

decodeModel : Decoder Model
decodeModel = Decode.map6 Model
    (Decode.succeed "")
    (field "What" string)
    (field "Rows" (list decodeRow))
    (field "Data" (dict decodeField))
    (Decode.succeed Nothing)
    (Decode.succeed Dict.empty)

decodeRow : Decoder Row
decodeRow =
  (field "Type" string)
    |> Decode.andThen (\str ->
        case str of
          "TEXT" ->
            Decode.map StringRow decodeBasicRowData
          "TEXTAREA" ->
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
    (Decode.succeed "")

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
  | Validation (Result Http.Error PostResponse)

update : Msg -> ResultModel -> (ResultModel, Cmd Msg)
update msg resultModel =
  case resultModel of
    Err x -> (resultModel, Cmd.none)
    Ok model ->
      let (newModel, cmd) =
        case msg of
          NewLocation menuMsg -> (model, Cmd.none)
          Cancel -> (model, Cmd.none)
          Save -> (model, Cmd.none)

          UpdateField name newValue ->
            ({ model |
               fields = Dict.update name (updateFieldValue newValue) model.fields}
            , Cmd.none)

          BlurField -> (model, post model.url "validate" model.fields)

          Validation result -> validationUpdate result model
      in
        (Ok newModel, cmd)

validationUpdate : Result Http.Error PostResponse -> Model -> (Model, Cmd Msg)
validationUpdate result model =
  case result of
    Ok Okay ->
        (model, Cmd.none)
    Ok (Errors newErrors) ->
        ({ model | fieldErrors = newErrors }, Cmd.none)
    Ok (BadStatus status) ->
        ({ model | error = Just ("Bad Status: " ++ status) } -- TODO humanise this error message
        , Cmd.none)
    Err e ->
        ({ model | error = Just (toString e) }  -- TODO humanise this error message
        , Cmd.none)


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
      Http.post url body decodePostResponse

type PostResponse = Errors (Dict.Dict String Errors)
                  | Okay
                  | BadStatus String

decodePostResponse : Decoder PostResponse
decodePostResponse =
  (field "Status" string)
    |> Decode.andThen (\str ->
      case str of
        "OK" -> Decode.succeed Okay
        "ERRORS" -> Decode.map Errors (field "Errors" (dict (list string)))
        _ -> Decode.succeed (BadStatus str)
    )


-- VIEW

view : ResultModel -> Html Msg
view maybeModel =
  case maybeModel of
    Err msg ->
      div [] [ text  ("Load error: " ++ msg) ]
    Ok model ->
      Grid.container []
        [ h1 [] [ text ("EditForm: " ++ model.what) ]
        , case model.error of
            Nothing -> text ""
            Just err -> Alert.simpleDanger [] [ text err ]
        , Form.form [] ((List.map (rowView model) model.rows) ++ [(buttonView model)])
        , pre [] [ text (toString model.fields) ]
        ]

leftSize = Col.sm3
rightSize = Col.sm9

rowView : Model -> Row -> Html Msg
rowView model row =
  case row of
    StringRow data ->
      inputRowView model textInputView data
    TextRow data ->
      inputRowView model textareaInputView data
    Group label rows ->
      Grid.row [ Row.attrs [ Spacing.mb4 ]]
        [ Grid.col [ Col.sm12 ] (List.map (rowView model) rows) ]

inputRowView model inputView data =
  let
    errors = Dict.get data.id model.fieldErrors
    errorList = case errors of
      Nothing -> []
      Just errorList -> errorList
    errorsHtml = [ Form.invalidFeedback [] (List.map text errorList) ]

    danger = errorList /= []
    inputHtml = [ inputView data model.fields danger ]
    helpHtml = if data.help /= "" then [Form.help [] [ text data.help ]] else []
  in
    Form.row []
        [ Form.colLabel [ leftSize, Col.attrs [Html.Attributes.for data.id] ] [ text data.label]
        , Form.col [ rightSize ] (inputHtml ++ errorsHtml ++ helpHtml)
        ]

textInputView : BasicRowData -> Fields -> Bool -> Html Msg
textInputView data fields danger =
  let
    dangerAttr = if danger then [ Input.danger ] else []
  in
    Input.text
      ([ Input.id data.id
       , Input.onInput (UpdateField data.id)
       , Input.attrs [ Html.Events.onBlur BlurField ]
       , Input.value (getFieldValue fields data.id)
       ] ++ dangerAttr)

textareaInputView : BasicRowData -> Fields -> Bool -> Html Msg
textareaInputView data fields danger =
  let
    dangerAttr = if danger then [ Textarea.danger ] else []
  in
    Textarea.textarea
      ([ Textarea.id data.id
       , Textarea.onInput (UpdateField data.id)
       , Textarea.attrs [ Html.Events.onBlur BlurField ]
       , Textarea.value (getFieldValue fields data.id)
       ] ++ dangerAttr)

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


