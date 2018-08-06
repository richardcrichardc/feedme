module Util.Form exposing (..)

import Html exposing (..)
import Html.Attributes
import Bootstrap.Button as Button
import Bootstrap.Utilities.Spacing as Spacing

spinner =
  img [ Html.Attributes.class "spinner", Html.Attributes.src "/assets/save-spinner-ba4f7d.gif" ] []

cancelSaveButtonView : Bool -> Bool -> msg -> msg -> Html msg
cancelSaveButtonView saveDisabled saving cancelCmd saveCmd =
  div
    []
    [ Button.button
       [ Button.primary
       , Button.disabled saving
       , Button.onClick cancelCmd
       ]
       [ text "Cancel" ]
    , spinnerButton "Save" saveDisabled saving saveCmd
    ]


spinnerButton : String -> Bool -> Bool -> msg -> Html msg
spinnerButton title disabled spinning onClickCmd =
  let
    innerHtml = if spinning then
                [ text (title ++ " ")
                , spinner
                ]
              else
                [ text title ]
  in
    Button.button
     [ Button.primary
     , Button.attrs [ Spacing.ml1 ]
     , Button.disabled (disabled || spinning)
     , Button.onClick onClickCmd
     ]
     innerHtml

