--  https://github.com/gpremer/elm-sse-ports/blob/master/src/elm/SSE.elm - MIT Licence

port module Util.SSE
    exposing
        ( SsEvent
        , EventType
        , Endpoint
        , SseAccess
        , SseEventDecoder
        , hasListenerFor
        , create
        , withoutAnyListener
        , withListener
        , withUntypedListener
        , withoutListener
        , withoutUntypedListener
        , serverSideEvents
        )

import Dict exposing (..)
import Maybe.Extra


type alias SsEvent =
    { data : String
    , eventType : String
    , id : Maybe String
    }


{-
   | A function that takes an SseEvent, of a specific type, and converts it to a domain-specific class.
-}


type alias SseEventDecoder msg =
    SsEvent -> msg


type alias Endpoint =
    String


type alias EventType =
    String


type alias SseAccess msg =
    { endpoint : Endpoint
    , noopMessage : msg
    , decoders : Dict String (SseEventDecoder msg)
    , untypedDecoder : Maybe (UntypedSseEventDecoder msg)
    }


hasListenerFor : EventType -> SseAccess msg -> Bool
hasListenerFor eventType sseAccess =
    Dict.member eventType sseAccess.decoders


{-| Create a new SseAccess instance. This is instance is not yet listening for SSE events. That only happens when the
first listener is attached.
-}
create : Endpoint -> msg -> SseAccess msg
create endpoint noop =
    SseAccess endpoint noop Dict.empty Nothing


{-| Adds a listener for a specific event type. Whenever such an event is received, it is passed as an SsEvent to the
provided decoder function and the result of decoding is then pumped out of the subscription. If there is already a
listener for the event type, it is replaced by the new one.
-}
withListener : EventType -> SseEventDecoder msg -> SseAccess msg -> ( SseAccess msg, Cmd msg )
withListener eventType eventDecoder sseAccess =
    let
        cmd =
            if hasListeners sseAccess then
                if Dict.member eventType sseAccess.decoders then
                    Cmd.none
                    -- All JS listener are the same, no need to set again
                else
                    addListenerJS ( sseAccess.endpoint, Just eventType )
            else
                createEventSourceAndAddListenerJS ( sseAccess.endpoint, Just eventType )
    in
        ( { sseAccess | decoders = Dict.insert eventType eventDecoder sseAccess.decoders }
        , cmd
        )


hasListeners : SseAccess msg -> Bool
hasListeners sseAccess =
    (Maybe.Extra.isJust sseAccess.untypedDecoder) || not (Dict.isEmpty sseAccess.decoders)


port addListenerJS : ( Endpoint, Maybe EventType ) -> Cmd msg


port createEventSourceJS : Endpoint -> Cmd msg




-- Needed because Cmd.batch is not ordered


port createEventSourceAndAddListenerJS : ( Endpoint, Maybe EventType ) -> Cmd msg


serverSideEvents : SseAccess msg -> Sub msg
serverSideEvents sseAccess =
    Sub.batch
        [ ssEventsJS <| decodersToEventMapper sseAccess
        , Maybe.withDefault Sub.none (Maybe.map ssUntypedEventsJS sseAccess.untypedDecoder)
        ]


decodersToEventMapper : SseAccess msg -> SsEvent -> msg
decodersToEventMapper sseAccess event =
    let
        maybeMsg =
            maybeMap (Dict.get event.eventType sseAccess.decoders) event

        -- by design we'll always find a decoder
    in
        Maybe.withDefault (sseAccess.noopMessage) maybeMsg


maybeMap : Maybe (a -> b) -> a -> Maybe b
maybeMap maybeF a =
    Maybe.map (\f -> f a) maybeF


port ssEventsJS : (SsEvent -> msg) -> Sub msg
