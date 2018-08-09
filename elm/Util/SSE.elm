--  https://github.com/gpremer/elm-sse-ports/blob/master/src/elm/SSE.elm - MIT Licence

port module Util.SSE exposing ( .. )

import Json.Decode exposing (Decoder, Value, decodeString, map2, field, string, value)

type alias Event =
    { event : String
    , data : Value
    }

port createEventSource : String -> Cmd msg
port ssEvents : (String -> msg) -> Sub msg

eventDecoder : Decoder Event
eventDecoder =
    map2 Event
        (field "Event" string)
        (field "Data" value)

decodeEvent : String -> Result String Event
decodeEvent event =
    decodeString eventDecoder event

