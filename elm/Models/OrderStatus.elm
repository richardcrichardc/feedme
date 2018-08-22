module Models.OrderStatus exposing (..)

import Json.Decode.Pipeline exposing (decode, required, custom)
import Json.Decode as Decode exposing (Decoder, succeed, fail, field, andThen, int, string)
import Date
import Time


type alias StatusUpdate =
  { number : Int
  , status : OrderStatus
  }

type OrderStatus
  = New Time.Time
  | Ready
  | Expected Time.Time
  | PickedUp
  | Rejected

statusUpdateDecoder : Decoder StatusUpdate
statusUpdateDecoder =
  decode StatusUpdate
      |> required "Number" int
      |> custom statusDecoder

dateDecoder : String -> Decoder Time.Time
dateDecoder dateString =
  case Date.fromString dateString of
    Ok date -> succeed (Date.toTime date)
    Err err -> fail err


statusDecoder : Decoder OrderStatus
statusDecoder =
  let
    dateBit status str =
      case Date.fromString str of
        Ok date -> succeed (status (Date.toTime date))
        Err err -> fail err
    statusBit str =
        case str of
          "New" ->
            field "StatusDate" string
              |> andThen (dateBit New)
          "Ready" ->
            succeed Ready
          "Expected" ->
            field "StatusDate" string
              |> andThen (dateBit Expected)
          "PickedUp" ->
            succeed PickedUp
          "Rejected" ->
            succeed Rejected
          _ ->
            fail ("Bad Status: " ++ str)
  in
    field "Status" string |> andThen statusBit

comparison : OrderStatus -> OrderStatus -> Basics.Order
comparison a b =
  case a of
    New aCreated->
      case b of
        New bCreated-> compare aCreated bCreated
        Ready -> LT
        Expected _ -> LT
        PickedUp -> LT
        Rejected -> LT
    Expected aExpected ->
      case b of
        New _ -> GT
        Ready -> GT
        Expected bExpected -> compare aExpected bExpected
        PickedUp -> LT
        Rejected -> LT
    Ready ->
      case b of
        New _ -> GT
        Ready -> EQ
        Expected _ -> LT
        PickedUp -> LT
        Rejected -> LT
    PickedUp ->
      case b of
        New _ -> GT
        Ready -> GT
        Expected _ -> GT
        PickedUp -> EQ
        Rejected -> LT
    Rejected ->
      case b of
        New _ -> GT
        Ready -> GT
        Expected _ -> GT
        PickedUp -> GT
        Rejected -> EQ
