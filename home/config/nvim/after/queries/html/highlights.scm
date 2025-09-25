; extends

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-action"))

((attribute_name) @stimulus-controller
    (#match? @stimulus-controller "data-controller"))

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-.*-outlet"))

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-.*-value"))

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-.*-target")
    (#not-match? @stimulus-attribute "data-ga4-.*-target"))

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-.*-class"))

((attribute_name) @stimulus-attribute
    (#match? @stimulus-attribute "data-.*-param"))


; ((attribute (attribute_name) @constant
;     ((#match? @constant "data-controller")
;     (quoted_attribute_value
;     (attribute_value) @markdown.strong))))
