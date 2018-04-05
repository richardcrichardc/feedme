module Rails exposing (..)

import Http
import Json.Encode as Encode
import Json.Decode as Decode

type Msg = FormError String
         | FormRedirect String

type alias FormTarget =
  { method : String
  , url : String
  , auth_token : String
  }

type alias FormFlags fields =
  { target : FormTarget
  , fields : fields
  }

submitForm : FormTarget -> String -> Encode.Value -> Cmd Msg
submitForm target name value =
  let
    encoder = Encode.object
                [ (name, value)
                , ("authenticity_token", Encode.string target.auth_token)
                ]
    decoder = Decode.field "redirect" Decode.string
    request = Http.request
              { method = target.method
              , headers = [ ]
              , url = target.url
              , body = Http.jsonBody encoder
              , expect = Http.expectJson decoder
              , timeout = Nothing
              , withCredentials = False
              }
  in
    Http.send responseCmd request

responseCmd : Result Http.Error String -> Msg
responseCmd resp = case resp of
    Ok location -> FormRedirect location
    Err err -> FormError (httpErrorToString err)

httpErrorToString : Http.Error -> String
httpErrorToString err = --"Oh oh: http error"
  case err of
    Http.BadUrl str -> "Client Error (BadUrl " ++ str ++ ")"
    Http.Timeout -> "Timeout"
    Http.NetworkError -> "Network Error"
    Http.BadStatus resp -> if resp.status.code == 422 then
                              case Decode.decodeString (Decode.list Decode.string) resp.body  of
                                Ok str -> String.join " " str
                                Err str -> "Server Error (Bad Error)"
                            else
                              "Server Error (" ++ toString resp.status.code ++ " " ++resp.status.message ++ ")"
    Http.BadPayload resp str -> "BadPayload: " ++ resp
