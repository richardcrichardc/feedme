module Menu exposing (..)

import Json.Decode as Decode
import Html exposing (..)
import Html.Attributes exposing (style, class, src, id, href)
import Html.Events exposing (onClick)
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Bootstrap.Button as Button
import Bootstrap.Table as Table

-- types

type Msg
    = Add OrderItem

type alias Menu =
  { title : String
  , items : List MenuItem
  }

type alias MenuItem =
  { id : Int
  , name : String
  , desc : String
  , price : Float
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
  , each : Float
  , total : Float
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
menuDecoder = Decode.map2 Menu
                (Decode.field "title" Decode.string)
                (Decode.field "items" (Decode.list itemDecoder))


itemDecoder: Decode.Decoder MenuItem
itemDecoder = Decode.map4 MenuItem
                (Decode.field "id" Decode.int)
                (Decode.field "name" Decode.string)
                (Decode.field "desc" Decode.string)
                (Decode.field "price" Decode.float)

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
      div [] [ div [] (List.map (itemView order) menu.items) ]

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
             , Button.button [ Button.primary, Button.onClick (Add { id=item.id, qty=1 })] [ text "Add" ]
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

priceString : Float -> String
priceString price = "$" ++ (format usLocale price)


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

invoiceTotalLine : Float -> Table.Row Msg
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
    menuItem = menuItemForId menu.items orderItem.id
  in
    { qty = orderItem.qty,
      desc = menuItem.name,
      each = menuItem.price,
      total = (toFloat orderItem.qty) * menuItem.price
    }

menuItemForId : List MenuItem -> Int -> MenuItem
menuItemForId items id =
  case items of
    [] -> MenuItem -1 "Error" "Error" -1.0
    (x::xs) ->
      if x.id == id then
        x
    else
        menuItemForId xs id

tdAlignRight = Table.cellAttr (class "text-right")
