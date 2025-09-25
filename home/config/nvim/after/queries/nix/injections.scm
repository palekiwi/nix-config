; extends

((apply_expression
   function: (apply_expression
     function: (select_expression
       attrpath: (attrpath
         attr: (identifier) @_func)))
   argument: (indented_string_expression
     (string_fragment) @injection.content))
 (#match? @_func "(^|\\.)writeNu(Bin)?$")
 (#set! injection.language "nu")
 (#set! injection.language "nu") 
 (#set! injection.combined))
