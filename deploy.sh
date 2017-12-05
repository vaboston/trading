#!/bin/bash


TEMPLATE='trading.rb'
VERSION='v0.5.1'
VMINEUR='5'
EUR_TO_TRADE='180'
declare -a arr=("BCH" "DASH" "XETCZ" "XETHZ" "XLTCZ" "XREPZ" "XXBTZ" "XXMRZ" "XXRPZ" "XZECZ")
for i in "${arr[@]}"
do
   echo "$i"
   cp init.rb "init-$i.rb"
   cp trading.rb "$i.$VERSION.rb"
   sed -i "s/XXBTZ/$i/g" "$i.$VERSION.rb"
   sed -i "s/XXBTZ/$i/g" "init-$i.rb"
   tmux new -s "$i-$VMINUER" "ruby init-$i.rb ; ruby $i.$VERSION.rb"
   #sed -i "s/v4.1/$VERSION/g" "$i.$VERSION.rb"
   #sed -i "s/PRICETOTRADE/$EUR_TO_TRADE/g" "$i.$VERSION.rb"
   # or do whatever with individual element of the array
done
