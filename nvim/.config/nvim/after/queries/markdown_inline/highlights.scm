;; extends

; Conceal backticks in `code` with a space — hides the delimiter without collapsing width
((code_span_delimiter) @markup.raw
  (#set! conceal " "))

; Conceal _ italic delimiters with · so text doesn't shift when cursor leaves the line
; #eq? matches only single-underscore delimiters (italic), not __ (bold)
((emphasis_delimiter) @markup.italic
  (#eq? @markup.italic "_")
  (#set! conceal "·"))

; Conceal all bold delimiters (* or _) with · — applies inside any strong_emphasis node
(strong_emphasis
  (emphasis_delimiter) @markup.strong
  (#set! conceal "·"))

; Capture the whole **...** node as @markup.strong.asterisk for blue coloring.
; @_delim is a throwaway capture used only to test the delimiter character via #eq?.
; Matching on the child delimiter is the only way to distinguish ** from __ bold,
; since both produce the same strong_emphasis parent node type.
((strong_emphasis
  (emphasis_delimiter) @_delim) @markup.strong.asterisk
  (#eq? @_delim "*"))

; Same as above but for __...__ bold → @markup.strong.underscore for purple coloring
((strong_emphasis
  (emphasis_delimiter) @_delim) @markup.strong.underscore
  (#eq? @_delim "_"))
