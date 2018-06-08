module Util.ErrorDialog exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


type alias Dialog parentMsg = Maybe (Model parentMsg)

dialog : String -> Maybe (String, parentMsg) -> Maybe (String, parentMsg) -> Dialog parentMsg
dialog title button details =
  Just
    <| Model title button details False

toggleDetails : Dialog parentMsg -> Dialog parentMsg
toggleDetails maybeModel =
  case maybeModel of
    Nothing ->
      Nothing
    Just model ->
      Just { model | showDetails = not model.showDetails }

--

type alias Model parentMsg =
  { title : String
  , button : Maybe (String, parentMsg)
  , details : Maybe (String, parentMsg)
  , showDetails : Bool
  }

view : Dialog parentMsg -> Html parentMsg
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
                    button [ onClick action ] [ text label ]
              , text " "
              , case model.details of
                  Nothing ->
                    text ""
                  Just (_, action) ->
                    button
                      [ onClick action ]
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
              Just (details, _) ->
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
