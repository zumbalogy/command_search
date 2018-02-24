
One potential future feature (besides more cusomizable syntax and all)
would be to be able to specify a certian number of matches. like,
this name field must have the string ":)" 3 times. having
an option  to pass though to real regexes might solve this.


right now, a<b<c is lexed as a,<,b,<,c and then parsed as
(< a (< b c)), but should maybe be parsed as (< a b c),
or lexed to the logical equavalent, (and (< a b) (< b c))
as to keep the comparison logic binary. the alternative
is to not allow this syntax.


right now there will be issues with 'foo:-bar'.

right now "" is treated as a valid quoted string.

it might be good to have a way to tell "collection" types (paren, or, minus)
from other nest types (compare and command) in the ast, to avoid code like

     [:paren, :pipe, :minus].include?(x[:nest_type])

TODO: integration specs with DB, test for error messages and such.