module Menu exposing (..)

import Json.Decode as Decode
import Html exposing (..)
import Html.Attributes exposing (style, class, src, id, href)
import Html.Events exposing (onClick)
import Bootstrap.Button as Button
import Bootstrap.Table as Table
import Bootstrap.Utilities.Spacing as Spacing

-- types

type alias Money = Int

type Msg
    = Add OrderItem

type alias Menu = List MenuItem

type alias MenuItem =
  { id : Int
  , name : String
  , desc : String
  , price : Money
  }

type alias Order = List OrderItem

type alias OrderItem =
  { id : Int
  , qty : Int
  }

type alias Invoice = List InvoiceLine

type alias InvoiceLine =
  { qty : Int
  , desc : String
  , each : Int
  , total : Money
  }


-- state

orderAdd : OrderItem -> Order -> Order
orderAdd item order =
  case order of
    [] -> [ item ]
    (x::xs) ->
      if x.id == item.id then
        { id=x.id, qty=x.qty+item.qty} :: xs
      else
        x :: (orderAdd item xs)

decode: String -> Result String Menu
decode str =
  Decode.decodeString menuDecoder str

menuDecoder: Decode.Decoder Menu
menuDecoder = Decode.list itemDecoder


itemDecoder: Decode.Decoder MenuItem
itemDecoder = Decode.map4 MenuItem
                (Decode.field "Id" Decode.int)
                (Decode.field "Name" Decode.string)
                (Decode.field "Desc" Decode.string)
                (Decode.field "Price" Decode.int)

-- views


maybeMenuView : Maybe Menu -> Order -> Html Msg
maybeMenuView menu_ order =
  case menu_ of
    Just menu ->
      menuView menu order
    Nothing ->
      text "No menu"


menuView : Menu -> Order -> Html Msg
menuView menu order =
  if menu == [] then
    text "Empty menu"
  else
    div [] [ div [] (List.map (itemView order) menu) ]


itemView : Order -> MenuItem -> Html Msg
itemView order item =
  let
    heading = String.concat [item.name, " – ", priceString item.price]
    qty = itemQty item.id order
    qtyHtml =
      if qty > 0 then
        span [ style [ ("color", "blue") ] ] [ text ((toString qty) ++ " in order ") ]
      else
        text ""
  in
    div
      []
      [ h3 [] [ text heading ]
      , p [] [ text item.desc ]
      , p [] [
              qtyHtml
             , Button.button [ Button.primary, Button.onClick (Add { id=item.id, qty=1 })] [ text "+" ]
             , Button.button [ Button.primary, Button.attrs [ Spacing.ml1 ], Button.onClick (Add { id=item.id, qty=-1 })] [ text "-" ]
             ]
      ]

itemQty : Int -> Order -> Int
itemQty id order =
  case order of
    [] -> 0
    (x::xs) ->
      if x.id == id then
        x.qty
      else
        itemQty id xs


priceString : Money -> String
priceString price =
  let
    dollarsStr = toString (price // 100)
    cents = rem (abs price) 100
    centsStr =
      if cents < 10 then
        "0" ++ (toString cents)
      else
        toString cents
  in
  "$" ++ dollarsStr ++ "." ++ centsStr


orderTotals : Menu -> Order -> (String, String)
orderTotals menu order =
  let
    invoice = orderInvoice menu order
    totalItems = List.sum (List.map .qty invoice)
    totalPrice = List.sum (List.map .total invoice)
  in
    (toString totalItems, priceString totalPrice)


invoiceView : Menu -> Order -> Html Msg
invoiceView menu order =
  let
    invoice = orderInvoice menu order
    total = List.sum (List.map .total invoice)
    lines = (List.map invoiceLineView invoice) ++ [invoiceTotalLine total]
  in
  Table.simpleTable
    ( Table.simpleThead
      [ Table.th [] [ text "Qty" ]
      , Table.th [] [ text "Item" ]
      , Table.th [ tdAlignRight ] [ text "Total" ]
      ]
    , Table.tbody [] lines
    )

invoiceLineView : InvoiceLine -> Table.Row Msg
invoiceLineView line =
  Table.tr []
    [ Table.td [] [ text (toString line.qty) ]
    , Table.td [] [ text line.desc ]
    , Table.td [ tdAlignRight ] [ text (priceString line.total) ]
    ]

invoiceTotalLine : Money -> Table.Row Msg
invoiceTotalLine total =
  Table.tr []
    [ Table.td [] []
    , Table.td [] []
    , Table.td [ tdAlignRight ] [ text (priceString total) ]
    ]

orderInvoice : Menu -> Order -> Invoice
orderInvoice menu order =
  List.map (orderItemInvoiceLine menu) order

orderItemInvoiceLine : Menu -> OrderItem -> InvoiceLine
orderItemInvoiceLine menu orderItem =
  let
    menuItem = menuItemForId menu orderItem.id
  in
    { qty = orderItem.qty,
      desc = menuItem.name,
      each = menuItem.price,
      total = orderItem.qty * menuItem.price
    }

menuItemForId : List MenuItem -> Int -> MenuItem
menuItemForId items id =
  case items of
    [] -> MenuItem -1 "Error" "Error" -1
    (x::xs) ->
      if x.id == id then
        x
    else
        menuItemForId xs id

tdAlignRight = Table.cellAttr (class "text-right")
