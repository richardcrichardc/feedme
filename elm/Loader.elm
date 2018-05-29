module Loader exposing (..)

import Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode exposing (Decoder, Value, decodeValue)

type Msg pageMsg
  = Refresh
  | ToggleDetails
  | CustomAction pageMsg
  | PageMsg pageMsg

type Error pageMsg
  = NoError
  | FlagDecodeError String
  | PageError String String pageMsg (Maybe String)

type alias LoaderModel model pageMsg =
  { error : Error pageMsg
  , showDetails : Bool
  , model : Maybe model
  }


programWithFlags
  : { flagDecodeFn : Value -> Result String model
    , update : pageMsg -> model -> Error pageMsg -> (model, Error pageMsg, Cmd pageMsg)
    , view : model -> Html.Html pageMsg
    }
  -> Program Value (LoaderModel model pageMsg) (Msg pageMsg)

programWithFlags spec =
  Html.programWithFlags
    { init = init spec.flagDecodeFn
    , view = view spec.view
    , update = update spec.update
    , subscriptions = always Sub.none
    }

programWithFlagsDecoder
  : { flagDecoder : Decoder model
    , update : pageMsg -> model -> Error pageMsg -> (model, Error pageMsg, Cmd pageMsg)
    , view : model -> Html.Html pageMsg
    }
  -> Program Value (LoaderModel model pageMsg) (Msg pageMsg)

programWithFlagsDecoder spec =
  Html.programWithFlags
    { init = init (decodeValue spec.flagDecoder)
    , view = view spec.view
    , update = update spec.update
    , subscriptions = always Sub.none
    }

init : (Value -> Result String model) -> Value -> (LoaderModel model pageMsg, Cmd msg)
init decodeFn flags =
  case decodeFn flags of
    Ok model ->
      (LoaderModel NoError False (Just model), Cmd.none)
    Err err ->
      (LoaderModel (FlagDecodeError err) False Nothing, Cmd.none)

update :
  (pageMsg -> model -> Error pageMsg -> (model, Error pageMsg, Cmd pageMsg))
  -> Msg pageMsg
  -> LoaderModel model pageMsg
  -> (LoaderModel model pageMsg, Cmd (Msg pageMsg))

update modelUpdate msg loaderModel =
  case msg of
    Refresh ->
      (loaderModel, Navigation.reload)
    ToggleDetails ->
      ({ loaderModel | showDetails = not loaderModel.showDetails }, Cmd.none)
    CustomAction pageMsg ->
      let
        noErrorModel = { loaderModel | error = NoError }
      in
        updatePage modelUpdate pageMsg noErrorModel
    PageMsg pageMsg ->
        updatePage modelUpdate pageMsg loaderModel

updatePage :
  (pageMsg -> model -> Error pageMsg -> (model, Error pageMsg, Cmd pageMsg))
  -> pageMsg
  -> LoaderModel model pageMsg
  -> (LoaderModel model pageMsg, Cmd (Msg pageMsg))

updatePage modelUpdate pageMsg loaderModel=
  case loaderModel.model of
    Nothing ->
      (loaderModel, Cmd.none)
    Just model ->
      let
        (modelOut, errorOut, pageMsgOut) = modelUpdate pageMsg model loaderModel.error
      in
        ({ loaderModel |
            model = Just modelOut,
            error = errorOut }
        , Cmd.map PageMsg pageMsgOut)


view : (model -> Html pageMsg) -> LoaderModel model pageMsg -> Html (Msg pageMsg)
view modelView loaderModel =
  let
    errorHtml =
      case loaderModel.error of
        NoError -> []
        FlagDecodeError err ->
          [ errorView "Page Load Error" "Reload" Refresh loaderModel.showDetails (Just err) ]
        PageError title buttonTitle pageMsg details ->
          [ errorView title buttonTitle (CustomAction pageMsg) loaderModel.showDetails details ]
    mainHtml =
      case loaderModel.model of
        Nothing -> []
        Just model -> [ Html.map PageMsg (modelView model) ]

  in
    div [] (errorHtml ++ mainHtml)

errorView : String -> String -> (Msg pageMsg) -> Bool -> Maybe String -> Html (Msg pageMsg)
errorView title buttonTitle buttonMsg showDetails details =
  let
    detailButton = if showDetails then
                      "Hide Details"
                    else
                      "Show Details"
  in
    div
      [ style
          [ ("all", "initial")
          , ("position", "fixed")
          , ("top", "0")
          , ("left", "0")
          , ("bottom", "0")
          , ("right", "0")
          , ("z-index", "1000")
          , ("font-family", "sans-serif")
          ]
      ]
      [ div
          [ style
            [ ("background-color", "white")
            , ("color", "black")
            , ("border", "1px solid black")
            , ("box-shadow", "0.5em 0.5em 0.5em #ccc")
            , ("padding", "0.5em 1em")
            , ("width", "75%")
            , ("max-width", "600px")
            , ("text-align", "center")
            , ("position", "relative")
              -- center in window
            , ("top", "50%")
            , ("left", "50%")
            , ("transform", "translate(-50%, -50%)")
            ]]
          [ div [ style
                  [ ("margin-bottom", "1em")
                  , ("font-weight", "bold")
                  ]
                ]
                [ text title ]
          , p [ ]
              [ button [ onClick buttonMsg ] [ text buttonTitle ]
              , text " "
              , case details of
                  Nothing ->
                    text ""
                  Just details ->
                    button [ onClick ToggleDetails ] [ text detailButton ]
              ]
          , case details of
              Nothing ->
                text ""
              Just details ->
                detailView showDetails details
          ]
      ]

detailView : Bool -> String -> Html (Msg pageMsg)
detailView showDetails details =
  if showDetails then
    p
      [ style
          [ ("background-color", "#ccc")
          , ("padding", "0.5em 1em")
          , ("overflow-wrap", "break-word")
          , ("text-align", "left")
          , ("font-family", "monospace")
          ]
      ]
      [ text details ]
  else
    text ""
