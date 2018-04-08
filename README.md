
One potential future feature (besides more cusomizable syntax and all)
would be to be able to specify a certian number of matches. like,
this name field must have the string ":)" 3 times. having
an option  to pass though to real regexes might solve this.


right now, a<b<c is lexed as a,<,b,<,c and then parsed as
(< a (< b c)), but should maybe be parsed as (< a b c),
or lexed to the logical equavalent, (and (< a b) (< b c))
as to keep the comparison logic binary.
the alternative is to not allow this syntax.

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

Note: it should also have a way to test presence of something that
is also searchable as a string. so, as an example, "error:'not found'|error:false"
or some such could work.


TODO: support arrays (and maybe other nesting/relations)


TODO: consider adding support for 'backwards' compares like 50<grade instead of grade>50
 -- note that this would potentially be problematic for fields that share a name with
 -- something that chronic could parse as a date. but could  just default to left side
 -- is the field. but maybe less is more when it comes to magical behaviour.


Right now, a blindspot if you want to search 'foo:"tRue"' and have have tRue not
be case sensitive. (since quotes are used to escape from true part if thats enabled
but also used to preserve case)


TODO: rubocop (add it to circleCI too)


Search across feilds
ann
ann orange

Seach specific values and fields
"Ann"
color:orange

Use aliases
favorite_color:orange
color:red
(maybe do points/score)

Check booleans and existance
admin:true
score:false

Match with logical ORs
red|blue
red|blue|bob

Match with logical NOTs
-red
-(red|blue)
(green admin) | john

Search ranges and dates (via the Chronic Gem)
score<=100
born>today

----------
(foo?) causes error if attempted to be passed in URL, so maybe i should have warning
for URL safe searches or so.

chronic thinks that "2000" means 20:20 today, not year 2000.
also it would be nice if "monday" matched any date on a monday, not just like this monday.
 -- for command at least (maybe compare it makes less sense)

----------------------------

it might be nice to have an optional character, so that:
['a b', 'a b c', 'b c']
first two can be matched with the query "a b c?" (or so) instead of "(a b) | (a b c)"

-------------------------------

def q1(s); q(s, [], { b: Boolean }); end
  q1('b:false').should == {"$and"=>[{"b"=>{"$exists"=>true}}, {"b"=>{"$ne"=>true}}]}

could maybe be optomized to return b=>false

-------------------------------

TODO: test out problems of nesting " and ' quote types. currently
' quotes are run first but what should really happen is that the outtermost
quotes should run first or at least eat up inner nested quotes.
