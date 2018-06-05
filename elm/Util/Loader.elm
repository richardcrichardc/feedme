module Util.Loader exposing (..)

import Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode exposing (Value)
import Json.Decode exposing (Decoder, decodeValue)
import Util.ErrorDialog as ErrorDialog


programWithFlags
  : { decoder : Decoder pageModel
    , update : pageMsg -> pageModel -> (pageModel, Cmd pageMsg)
    , view : pageModel -> Html.Html pageMsg
    }
  -> Program Value (Model pageMsg pageModel) (Msg pageMsg)

programWithFlags spec =
  Html.programWithFlags
    { init = init (decodeValue spec.decoder)
    , view = view spec.view
    , update = update spec.update
    , subscriptions = always Sub.none
    }

--

type Msg pageMsg
  = Refresh
  | ErrorDialogMsg ErrorDialog.Msg
  | PageMsg pageMsg


type alias Model pageMsg pageModel =
  { errorDialog : ErrorDialog.Dialog (Msg pageMsg)
  , maybePageModel : Maybe pageModel
  }


init : (Value -> Result String pageModel) -> Value -> (Model pageMsg pageModel, Cmd (Msg pageMsg))
init decoder flags =
  case decoder flags of
    Ok model ->
      (Model Nothing (Just model), Cmd.none)
    Err err ->
      let
        errorDialog = ErrorDialog.dialog "Page Load Error" (Just ("Reload Page", Refresh)) (Just err)
      in
        (Model errorDialog Nothing, Cmd.none)


update :
  (pageMsg -> pageModel -> (pageModel, Cmd pageMsg))
  -> Msg pageMsg
  -> Model pageMsg pageModel
  -> (Model pageMsg pageModel, Cmd (Msg pageMsg))

update pageUpdate msg model =
  case msg of
    Refresh ->
      (model, Navigation.reload)
    ErrorDialogMsg msg ->
      let
        (updatedErrorDialog, cmd) = ErrorDialog.update msg model.errorDialog
      in
        ({ model | errorDialog = updatedErrorDialog}, Cmd.map ErrorDialogMsg cmd)
    PageMsg msg ->
      case model.maybePageModel of
        Nothing ->
          (model, Cmd.none)
        Just pageModel ->
          let
            (updatedPageModel, cmd) = pageUpdate msg pageModel
          in
            ({ model | maybePageModel = Just updatedPageModel}, Cmd.map PageMsg cmd)


view : (pageModel -> Html pageMsg) -> Model pageMsg pageModel -> Html (Msg pageMsg)
view pageView model =
  div []
    [ Html.map ErrorDialogMsg (ErrorDialog.view model.errorDialog)
    , case model.maybePageModel of
      Nothing ->
        text ""
      Just pageModel ->
        Html.map PageMsg (pageView pageModel)
    ]
