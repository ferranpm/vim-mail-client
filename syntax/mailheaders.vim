syn match delimiter "<>" contained conceal
syn match delimiter "\*" contained conceal
syn match delimiter "\$" contained conceal

syn match uid     '\*\d\+\*' contains=delimiter
syn match subject '\$.*\$'   contains=delimiter
syn match from    '<>.*<>'   contains=delimiter

hi def link delimiter Ignore
hi def link uid  Number
hi def link from Identifier
hi def link subject String
