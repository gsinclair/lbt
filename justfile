default: test

edit:
  nvim *.lua *.sty

test:
  make install
  (cd test && ../etc/build.sh general-test-document)

code-pdf:
  lualatex --shell-escape lbt-code && open lbt-code.pdf
