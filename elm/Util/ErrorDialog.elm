module Util.ErrorDialog exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


type alias Dialog parentMsg = Maybe (Model parentMsg)

dialog : String -> Maybe (String, parentMsg) -> Maybe String -> Dialog parentMsg
dialog title button details =
  Just
    <| Model title button details False

--

type alias Model parentMsg =
  { title : String
  , button : Maybe (String, parentMsg)
  , details : Maybe String
  , showDetails : Bool
  }

type Msg
  = ButtonPressed
  | ToggleDetails


update : Msg -> Dialog parentMsg -> (Dialog parentMsg, Cmd Msg)
update msg maybeModel =
  case maybeModel of
    Nothing ->
      (Nothing, Cmd.none)
    Just model ->
      let (newModel, cmd) =
        case msg of
          ButtonPressed ->
            (model, Cmd.none)
          ToggleDetails ->
            ({ model | showDetails = not model.showDetails } , Cmd.none)
      in
        (Just newModel, cmd)


view : Dialog parentMsg -> Html Msg
view maybeModel =
  case maybeModel of
    Nothing ->
      text ""
    Just model ->
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
                [ text model.title ]
          , p [ ]
              [ case model.button of
                  Nothing ->
                    text ""
                  Just (label, action) ->
                    button [ onClick ButtonPressed ] [ text label ]
              , text " "
              , case model.details of
                  Nothing ->
                    text ""
                  Just details ->
                    button
                      [ onClick ToggleDetails ]
                      [ text <|
                          if model.showDetails then
                            "Hide Details"
                          else
                            "Show Details"
                      ]
              ]
          , case model.details of
              Nothing ->
                text ""
              Just details ->
                if model.showDetails then
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
          ]
      ]
