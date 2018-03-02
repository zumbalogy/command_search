
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

TODO: handle strings vs symbols when doing command_types and such in systimatic way.

TODO: write a validator step and a user-defined-preprocessing step. call it transformer or something.
--- hmm, any string pre-processing could just be handled by the user.
--- but maybe a helper function that can be passed a string or regex, and
--- the string would be converted to a sane regex that handled word boundries
--- and casing and all. (and user could pass in own regex if they want to differnt
--- defaults).


TODO: make sure periods in strings work, like "Dr.Foo"
TODO: current commands are passed though as commands without validation.


Note: in example project, have a "sort by" example
