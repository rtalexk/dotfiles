;; extends

((code_span_delimiter) @markup.raw
  (#set! conceal " "))

((emphasis_delimiter) @markup.italic
  (#eq? @markup.italic "_")
  (#set! conceal " "))
