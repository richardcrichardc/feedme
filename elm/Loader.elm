module Loader exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode exposing (Decoder, Value, decodeValue)

type Error
  = NoError
  | DecodeError String

type alias LoaderModel model =
  { error : Error
  , model : Maybe model
  }


programWithFlags
  : { flagDecoder : Decoder model
    , update : msg -> model -> Error -> (model, Error, Cmd msg)
    , view : model -> Html.Html msg
    }
  -> Program Value (LoaderModel model) msg

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
      (LoaderModel NoError (Just model), Cmd.none)
    Err err ->
      (LoaderModel (DecodeError err) Nothing, Cmd.none)

update :
  (msg -> model -> Error -> (model, Error, Cmd msg))
    -> msg -> LoaderModel model -> (LoaderModel model, Cmd msg)
update modelUpdate msg loaderModel =
  case loaderModel.model of
    Nothing ->
      (loaderModel, Cmd.none)
    Just model ->
      let
        (modelOut, errorOut, msgOut) = modelUpdate msg model loaderModel.error
      in
        ({ loaderModel |
            model = Just modelOut,
            error = errorOut }
        , msgOut)

view : (model -> Html.Html msg) -> LoaderModel model -> Html.Html msg
view modelView loaderModel =
  let
    errorView =
      case loaderModel.error of
        NoError -> []
        DecodeError err -> [
          div [ style [("color", "red")]] [ text err ]
        ]

    mainView =
      case loaderModel.model of
        Nothing -> []
        Just model -> [ modelView model ]

  in
    div [] (errorView ++ mainView)


