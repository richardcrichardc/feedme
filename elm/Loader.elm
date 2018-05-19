module Loader exposing (..)

import Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode exposing (Decoder, Value, decodeValue)

type Msg pageMsg
  = Refresh
  | ToggleDetails
  | PageMsg pageMsg

type Error
  = NoError
  | FlagDecodeError String

type alias LoaderModel model =
  { error : Error
  , showDetails : Bool
  , model : Maybe model
  }


programWithFlags
  : { flagDecoder : Decoder model
    , update : pageMsg -> model -> Error -> (model, Error, Cmd pageMsg)
    , view : model -> Html.Html pageMsg
    }
  -> Program Value (LoaderModel model) (Msg pageMsg)

programWithFlags spec =
  Html.programWithFlags
    { init = init spec.flagDecoder
    , view = view spec.view
    , update = update spec.update
    , subscriptions = always Sub.none
    }

init : Decoder model -> Value -> (LoaderModel model, Cmd msg)
init decoder flags =
  case decodeValue decoder flags of
    Ok model ->
      (LoaderModel NoError False (Just model), Cmd.none)
    Err err ->
      (LoaderModel (FlagDecodeError err) False Nothing, Cmd.none)

update :
  (pageMsg -> model -> Error -> (model, Error, Cmd pageMsg))
  -> Msg pageMsg
  -> LoaderModel model
  -> (LoaderModel model, Cmd (Msg pageMsg))

update modelUpdate msg loaderModel =
  case msg of
    Refresh ->
      (loaderModel, Navigation.reload)
    ToggleDetails ->
      ({ loaderModel | showDetails = not loaderModel.showDetails }, Cmd.none)
    PageMsg pageMsg ->
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

view : (model -> Html pageMsg) -> LoaderModel model -> Html (Msg pageMsg)
view modelView loaderModel =
  let
    errorHtml =
      case loaderModel.error of
        NoError -> []
        FlagDecodeError err -> [
          errorView "Page Load Error" loaderModel.showDetails err
        ]

    mainHtml =
      case loaderModel.model of
        Nothing -> []
        Just model -> [ Html.map PageMsg (modelView model) ]

  in
    div [] (errorHtml ++ mainHtml)

errorView : String -> Bool -> String -> Html (Msg pageMsg)
errorView title showDetails details =
  let
    detailButton = if showDetails then
                      "Hide Details"
                    else
                      "Show Details"
  in
    div
      [ style
          [ ("position", "absolute")
          , ("top", "0")
          , ("left", "0")
          , ("right", "0")
          , ("z-index", "1000")
          ]
      ]
      [ div
          [ style
            [ ("background-color", "blue")
            , ("color", "white")
            , ("padding", "0.5em 1em")
            , ("width", "75%")
            , ("margin", "4em auto 0 auto")
            , ("text-align", "center")
            ]]
          [ div [ style [ ("margin-bottom", "1em") ]] [ text title ]
          , p [ ]
              [ button [ onClick Refresh ] [ text "Reload" ]
              , text " "
              , button [ onClick ToggleDetails ] [ text detailButton ]
              ]
          , detailView showDetails details
          ]
      ]

detailView : Bool -> String -> Html (Msg pageMsg)
detailView showDetails details =
  if showDetails then
    p
      [ style
          [ ("background-color", "gray")
          , ("padding", "0.5em 1em")
          , ("overflow-wrap", "break-word")
          , ("text-align", "left")
          ]
      ]
      [ text details ]
  else
    text ""
