module Models.Restaurant exposing (..)

import Json.Decode as Decode exposing (Decoder, Value, succeed, decodeValue, string, int)
import Json.Decode.Pipeline as Pipeline exposing (required, optional, hardcoded, resolve)

type alias Restaurant =
  { slug : String
  , name : String
  , address1 : String
  , address2 : String
  , town : String
  , phone : String
  , mapLocation : String
  , mapZoom : String
  , about : String
  }

decode : Decoder Restaurant
decode =
    Pipeline.decode Restaurant
      |> required "Slug" string
      |> required "Name" string
      |> required "Address1" string
      |> required "Address2" string
      |> required "Town" string
      |> required "Phone" string
      |> required "MapLocation" string
      |> required "MapZoom" string
      |> required "About" string
