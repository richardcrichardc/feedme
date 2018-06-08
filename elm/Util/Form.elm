module Util.Form exposing (..)

import Html exposing (..)
import Html.Attributes
import Bootstrap.Button as Button
import Bootstrap.Utilities.Spacing as Spacing

cancelSaveButtonView : Bool -> Bool -> msg -> msg -> Html msg
cancelSaveButtonView saveDisabled saving cancelCmd saveCmd =
  let
    saveHtml = if saving then
                    [ text "Saving "
                    , img [ Html.Attributes.class "spinner", Html.Attributes.src "/assets/save-spinner-ba4f7d.gif" ] []
                    ]
                  else
                    [ text "Save" ]
  in
    div
      []
      [ Button.button
         [ Button.primary
         , Button.disabled saving
         , Button.onClick cancelCmd
         ]
         [ text "Cancel" ]
      , Button.button
         [ Button.primary
         , Button.attrs [ Spacing.ml1 ]
         , Button.disabled (saveDisabled || saving)
         , Button.onClick saveCmd
         ]
         saveHtml
      ]
