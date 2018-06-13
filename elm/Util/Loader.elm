module Util.Loader exposing (..)

import Navigation exposing (Location)
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
  Navigation.programWithFlags
    DiscardLocation
    { init = init (\flags location -> (decodeValue spec.decoder flags, Cmd.none))
    , view = view spec.view
    , update = update spec.update
    , subscriptions = always Sub.none
    }

programWithFlags2
  :  (Location -> pageMsg)
  -> { init : Value -> Location -> (Result String pageModel, Cmd pageMsg)
     , update : pageMsg -> pageModel -> (pageModel, Cmd pageMsg)
     , view : pageModel -> Html.Html pageMsg
     , subscriptions : pageModel -> Sub pageMsg
     }
  -> Program Value (Model pageMsg pageModel) (Msg pageMsg)

programWithFlags2 locationToMsg spec =
  Navigation.programWithFlags
    (\location -> PageMsg (locationToMsg location))
    { init = init spec.init
    , view = view spec.view
    , update = update spec.update
    , subscriptions = subscriptions spec.subscriptions
    }


type Msg pageMsg
  = Refresh
  | ToggleDetails
  | PageMsg pageMsg
  | DiscardLocation Location


type alias Model pageMsg pageModel =
  { errorDialog : ErrorDialog.Dialog (Msg pageMsg)
  , maybePageModel : Maybe pageModel
  }


init : (Value -> Location -> (Result String pageModel, Cmd pageMsg)) -> Value -> Location -> (Model pageMsg pageModel, Cmd (Msg pageMsg))
init pageInit flags location =
  case pageInit flags location of
    (Ok model, cmd) ->
      (Model Nothing (Just model), Cmd.map PageMsg cmd)
    (Err err, cmd) ->
      let
        errorDialog = ErrorDialog.dialog "Page Load Error" (Just ("Reload Page", Refresh)) (Just (err, ToggleDetails))
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
    ToggleDetails ->
      ({ model | errorDialog = ErrorDialog.toggleDetails model.errorDialog}, Cmd.none)
    PageMsg msg ->
      case model.maybePageModel of
        Nothing ->
          (model, Cmd.none)
        Just pageModel ->
          let
            (updatedPageModel, cmd) = pageUpdate msg pageModel
          in
            ({ model | maybePageModel = Just updatedPageModel}, Cmd.map PageMsg cmd)
    DiscardLocation location->
      (model, Cmd.none)


view : (pageModel -> Html pageMsg) -> Model pageMsg pageModel -> Html (Msg pageMsg)
view pageView model =
  div []
    [ ErrorDialog.view model.errorDialog
    , case model.maybePageModel of
      Nothing ->
        text ""
      Just pageModel ->
        Html.map PageMsg (pageView pageModel)
    ]

subscriptions : (pageModel -> Sub pageMsg) -> Model pageMsg pageModel -> Sub (Msg pageMsg)
subscriptions pageSubs model =
  case model.maybePageModel of
    Nothing ->
      Sub.none
    Just pageModel ->
      Sub.map PageMsg (pageSubs pageModel)
