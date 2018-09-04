
One potential future feature (besides more customizable syntax and all)
would be to be able to specify a certain number of matches. like,
this name field must have the string ":)" 3 times. having
an option to pass though to real regexes might solve this.

right now, there are likely issues with comparing dates.

right now there will be issues with 'foo:-bar'.

it might be good to have a way to tell "collection" types (paren, or, minus)
from other nest types (compare and command) in the ast, to avoid code like

     [:paren, :pipe, :minus].include?(x[:nest_type])

TODO: it could be nice to be able to have an alias where the proper
name is off limits.

TODO: proper error messages and such.


Note: in example project, have a "sort by" example

Note: it should also have a way to test presence of something that
is also searchable as a string. so, as an example, "error:'not found'|error:false"
or some such could work.


TODO: support arrays (and maybe other nesting/relations)


TODO: consider adding support for 'backwards' compares like 50<grade instead of grade>50
 -- note that this would potentially be problematic for fields that share a name with
 -- something that chronic could parse as a date. but could  just default to left side
 -- is the field. but maybe less is more when it comes to magical behavior.


Right now, a blindspot if you want to search 'foo:"tRue"' and have have tRue not
be case sensitive. (since quotes are used to escape from true part if thats enabled
but also used to preserve case)


TODO: rubocop (add it to circleCI too)

Search across fields
ann
ann orange

Search specific values and fields
"Ann"
color:orange

Use aliases
favorite_color:orange
color:red
(maybe do points/score)

Check booleans and existence
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
a<b<c

----------
(foo?) causes error if attempted to be passed in URL, so maybe i should have warning
for URL safe searches or so.

chronic thinks that "2000" means 20:20 today, not year 2000.
also it would be nice if "monday" matched any date on a monday, not just like this monday.
 -- for command at least (maybe compare it makes less sense)

-------------------------------
