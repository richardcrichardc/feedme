#!/bin/bash -e

cd elm
chronic elm-make PlaceOrder.elm --output ../assets/elm.js --yes
cd ..

chronic npm run sass

go build -o gin-bin
