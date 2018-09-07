# Command Search
command_search is a Ruby gem to help users easily query collections.

command_search should make it a breeze to make gmail-style search bars, where
users can search for items that match `flamingos` or `author:herbert`, as well
as using negations, comparisons, ors, and ands.

command_search does not require an engine and should be easy to set up.

## SYNTAX
Normal queries like `friday dinner`, `shoelace`, or `treehouse` work normally,
but a user can specify using quotation marks if they want a search `'ann'` to
not match "anne" or `"bob"` to not match "bobby". Quoted searches are also
case sensitive and can match whole phrases, like `"You had me at HELLO."`.
Collections can also be queried in a few extra handy ways, all of which can
be used in combination.

| Command | Character            | Examples                               |
| ----    | -----                | ----------                             |
| Specify | `:`                  | `attachment:true`, `grade:A`           |
| And     | `(...)`              | `(error important)`, `liked poked` (Note: space is an implicit and) |
| Or      | `\|`                 | `color\|colour`, `red\|orange\|yellow` |
| Compare | `<`, `>`, `<=`, `>=` | `created_at<monday`, `100<=pokes`      |
| Negate  | `-`                  | `-error`, `-(sat\|sun)`                |

## LIMITATIONS
'Fuzzy' searching is not currently supported.

The only currently supported collections to query are MongoDB [link] collections
and in-memory arrays of hashes.
SQL support hopefully coming soon.

## DEPENDANCIES
Mongoid [link] is assumed if using command_search to search MongoDB.

Chronic [link] is currently used to parse user submitted dates, such as
'tuesday' or '1/1/11'. Chronic's handling of timezones and leap years and such
is not perfect, but is only used if 'Date' is declared as a field type in the config.

## INSTALL
Command Line:
```
gem install command_search
```
Gemfile:
```ruby
gem 'command_search'
```

## SETUP


## EXAMPLES
