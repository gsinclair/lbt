#!/bin/zsh

errors() {
  tail -40 test1.log |
    grep \.lua: |
    grep -v /vendor/ |
    sed 's/^.*\/luatex\/lbt/  lbt/' |
    sed 's/ in /\n                             in /'
}

clear
(cd ..; make install) && max_print_line=10000 lualatex -halt-on-error test1.tex

if [[ $? -eq 1 ]]; then
  echo
  echo '= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ='
  echo
  errors
fi
