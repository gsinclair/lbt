#!/bin/zsh

# Adapted from lbd-documents/Common/build.sh
# That should be considered the primary implementation.
# This might fall behind in any updates.

# The 'make install' line has been removed; do that separately.

# Usage:              etc/build.sh <Latex file>

project=$1

errors() {
  tail -40 $project.log |
    grep \.lua: |
    grep -v /vendor/ |
    sed 's/^.*\/luatex\/lbt/  lbt/' |
    sed 's/ in /\n                             in /'
}

max_print_line=10000 \
  lualatex --file-line-error --shell-escape --halt-on-error \
  $project.tex

if [[ $? -eq 1 ]]; then
  echo
  echo '= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ='
  echo
  errors
fi

