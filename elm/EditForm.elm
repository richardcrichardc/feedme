module EditForm exposing (..)

import Loader
import Navigation
import Json.Decode as Decode exposing (Decoder, Value, decodeValue, field, string, list, dict, bool)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)
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
  Loader.programWithFlags
    { flagDecoder = decodeModel
    , view = view
    , update = update
    }

-- MODEL

type alias Model =
  { url: String
  , cancelUrl : String
  , savedUrl : String
  , what : String
  , rows : List Row
  , fields : Fields
  , saving : Bool
  , dirty : Bool
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
  { value : String
  , errors : List String
  }

type alias Errors = List String

decodeModel : Decoder Model
decodeModel =
  decode Model
    |> hardcoded ""
    |> required "CancelUrl" string
    |> required "SavedUrl" string
    |> required "What" string
    |> required "Rows" (list decodeRow)
    |> required "Data" (dict decodeField)
    |> hardcoded False
    |> hardcoded False

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
        Decode.succeed (Field value [])
    )

-- UPDATE

type Msg
  = NewLocation Navigation.Location
  | UpdateField String String
  | BlurField
  | Save
  | Cancel
  | Validation String Fields (Result Http.Error PostResponse)
  | Retry String Fields

update : Msg -> Model -> Loader.Error Msg -> (Model, Loader.Error Msg, Cmd Msg)
update msg model error =
  case msg of
    NewLocation menuMsg -> (model, error, Cmd.none)
    UpdateField name newValue ->
      ({ model |
         dirty = True,
         fields = Dict.update name (updateFieldValue newValue) model.fields }
      , error
      , Cmd.none)
    BlurField ->
      ({ model |
         dirty = False }
      , error
      , if model.dirty then
          post model.url "VALIDATE" model.fields
        else
          Cmd.none
      )
    Validation action fields result -> validationUpdate action fields result model error
    Cancel -> (model, error, Navigation.load model.cancelUrl)
    Save -> ({ model |
               saving = True }
            , error
            , post model.url "SAVE" model.fields)
    Retry action fields ->
      (model
      , error
      , post model.url action fields)

validationUpdate : String -> Fields -> Result Http.Error PostResponse -> Model -> Loader.Error Msg -> (Model, Loader.Error Msg, Cmd Msg)
validationUpdate action fields result savingModel error =
  let
    model = { savingModel | saving = False}
  in
    case result of
      Ok Okay ->
          ({ model | fields = mergeErrors Dict.empty model.fields }, error, Cmd.none)
      Ok (Errors errors) ->
          ({ model | fields = mergeErrors errors model.fields }, error, Cmd.none)
      Ok Saved ->
          ({ model |
             fields = mergeErrors Dict.empty model.fields,
             saving = True } -- leave spinner in place until new page is loaded
          , error
          , Navigation.load model.savedUrl)
      Ok (BadStatus status) ->
          ( model
          , Loader.PageError "Server Error" "Retry" (Retry action fields) (Just ("Bad Status: " ++ status))
          , Cmd.none)
      Err e ->
        let
          title = case e of
            Http.NetworkError ->
              "Network Error"
            _ -> -- TODO handle other errors
              "Server Error"
        in
          ( model
          , Loader.PageError title "Retry" (Retry action fields) Nothing
          , Cmd.none)


updateFieldValue : String -> Maybe Field -> Maybe Field
updateFieldValue newValue field =
  case field of
    Just field -> Just { field | value = newValue }
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
    Http.send (Validation action fields) <|
      Http.post url body decodePostResponse

type PostResponse = Errors (Dict.Dict String Errors)
                  | Okay
                  | Saved
                  | BadStatus String

decodePostResponse : Decoder PostResponse
decodePostResponse =
  (field "Status" string)
    |> Decode.andThen (\str ->
      case str of
        "OK" -> Decode.succeed Okay
        "ERRORS" -> Decode.map Errors (field "Errors" (dict (list string)))
        "SAVED" -> Decode.succeed Saved
        _ -> Decode.succeed (BadStatus str)
    )

type alias ErrorsDict = Dict.Dict String Errors

mergeErrors : ErrorsDict -> Fields -> Fields
mergeErrors errors fields =
  let
    leftStep k a f = f
    bothStep k a b f = Dict.insert k { b | errors = a } f
    rightStep k b f = Dict.insert k { b | errors = [] } f
  in
    Dict.merge leftStep bothStep rightStep errors fields Dict.empty

-- VIEW

view : Model -> Html Msg
view model =
  Grid.container []
    [ h1 [] [ text ("EditForm: " ++ model.what) ]
    , Form.form [] ((List.map (rowView model) model.rows) ++ [(buttonView model)])
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


inputRowView : Model -> (BasicRowData -> Maybe Field -> Bool -> Html Msg) -> BasicRowData -> Html Msg
inputRowView model inputView data =
  let
    field = Dict.get data.id model.fields
    errorList = case field of
      Nothing -> ["MISSING"]
      Just field -> field.errors
    errorsHtml = [ Form.invalidFeedback [] (List.map text errorList) ]

    danger = errorList /= []
    inputHtml = [ inputView data field danger ]
    helpHtml = if data.help /= "" then [Form.help [] [ text data.help ]] else []
  in
    Form.row []
        [ Form.colLabel [ leftSize, Col.attrs [Html.Attributes.for data.id] ] [ text data.label]
        , Form.col [ rightSize ] (inputHtml ++ errorsHtml ++ helpHtml)
        ]

textInputView : BasicRowData -> Maybe Field -> Bool -> Html Msg
textInputView data field danger =
  let
    dangerAttr = if danger then [ Input.danger ] else []
  in
    Input.text
      ([ Input.id data.id
       , Input.onInput (UpdateField data.id)
       , Input.attrs [ Html.Events.onBlur BlurField ]
       , Input.value (fieldValue field)
       ] ++ dangerAttr)

textareaInputView : BasicRowData -> Maybe Field -> Bool -> Html Msg
textareaInputView data field danger =
  let
    dangerAttr = if danger then [ Textarea.danger ] else []
  in
    Textarea.textarea
      ([ Textarea.id data.id
       , Textarea.onInput (UpdateField data.id)
       , Textarea.attrs [ Html.Events.onBlur BlurField ]
       , Textarea.value (fieldValue field)
       ] ++ dangerAttr)

fieldValue : Maybe Field -> String
fieldValue field =
  case field of
    Just field -> field.value
    Nothing -> "MISSING"



buttonView : Model -> Html Msg
buttonView model =
  let
    fieldHasError _ field acc = acc || not (List.isEmpty field.errors)
    formHasError = Dict.foldl fieldHasError False model.fields
    saveDisabled = model.saving || formHasError
    saveHtml = if model.saving then
                    [ text "Saving "
                    , img [ Html.Attributes.class "spinner", Html.Attributes.src "/assets/save-spinner-ba4f7d.gif" ] []
                    ]
                  else
                    [ text "Save" ]
  in
    Form.row []
      [ Form.col [ leftSize ] []
      , Form.col [ rightSize ]
        [ Button.button
           [ Button.primary, Button.disabled model.saving, Button.onClick Cancel ]
           [ text "Cancel" ]
        , Button.button
           [ Button.primary, Button.attrs [ Spacing.ml1 ], Button.disabled saveDisabled, Button.onClick Save ]
           saveHtml
        ]
      ]


