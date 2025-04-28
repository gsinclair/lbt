default: test

edit:
  nvim *.lua *.sty

test:
  make install
  (cd test && ../etc/build.sh general-test-document)

code-pdf:
  lualatex --shell-escape lbt-code && open lbt-code.pdf

doc:
  make install
  (cd doc && ../etc/build.sh lbt-doc)
  # (cd doc && ../etc/build.sh lbt-examples)
