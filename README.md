# Command Search
[![Github Actions](https://github.com/zumbalogy/command_search/workflows/Tests/badge.svg)](https://github.com/zumbalogy/command_search/actions?query=workflow%3ATests)
[![Gem Version](https://badge.fury.io/rb/command_search.svg)](https://badge.fury.io/rb/command_search)
[![Downloads](https://img.shields.io/gem/dt/command_search.svg?style=flat)](https://rubygems.org/gems/command_search)

**command_search** is a Ruby gem to help users query collections.

It works with
[MongoDB](https://www.mongodb.com/),
[MySQL](https://www.mysql.com/),
[MariaDB 10](https://mariadb.org/),
[SQLite](https://www.sqlite.org/),
[PostgreSQL](https://www.postgresql.org/),
and arrays of hashes.

Note: MariaDB and Mysql5.x need to be
[specified](#Setup)
to `CommandSearch.build`.

It provides basic search functionality as well as as quotation, negation, comparison, date handling, OR, and AND logic, so users can search for `flamingos` or `author:herbert` or `price<200 discount`.

command_search makes it easy to add syntax and macros for users.
The query `A+` could be handled as `grade>=95`.
Some examples:
* `$99` --> `price:99`
* `starred` --> `liked_at:true` (to match non-nil values)
* `hair=blue` --> `hair:blue`
* `name:alice` --> `user_name:alice`
* `sent_by:me` --> `sent_by:59guwJphUhqfd2A` (but with the actual ID)

command_search is written with performance in mind and should have minimal overhead for most queries.
It does not require an engine and should be easy to set up.

An example Rails app using command_search:
[earthquake-search.herokuapp.com](https://earthquake-search.herokuapp.com/)
([code](https://github.com/zumbalogy/command_search_example)).

Feedback, questions, bug reports, pull requests, and suggestions are welcome.

## Install
Command Line:
```ruby
gem install command_search
```
Gemfile:
```ruby
gem 'command_search'
```

## Syntax
Basic queries like `friday dinner`, `shoelace`, or `treehouse` will perform order-agnostic case-insensitive partial matching per space-delineated part of the query.
The query `fire ants` will match "PANTS ON FIRE".

Quoted text can search for whole phrases or full names, such as `"You had me at HELLO!"` or `artist:"Ilya Repin"`.
Quoted text is case sensitive and only matches full words.
The query `"ann"` will not match "anne" or "ANN".


| Command | Character            | Examples                               |
| ----    | -----                | ----------                             |
| Specify | `:`                  | `attachment:true`, `grade:A`           |
| And     | `(...)`              | `(error important)`, `liked poked` (Space is an implicit AND) |
| Or      | `\|`                 | `color\|colour`, `red\|orange\|yellow` |
| Compare | `<`, `>`, `<=`, `>=` | `created_at<monday`, `100<=pokes`, `height>width`      |
| Negate  | `-`                  | `-error`, `-(sat\|sun)`                |

## Dependencies
[Chronic](https://github.com/mojombo/chronic)
is currently used to parse dates, such as `created_at>tuesday` or `send_on:1/1/11`.
Chronic's handling of timezones and leap years is not perfect.
It is only used if 'Date' is declared as a field type in the config.

## Limitations
The logic can be slow (100ms+) for queries that exceed 10,000 characters.
In public APIs or performance sensitive use cases, long inputs should
be truncated or otherwise accounted for.

Date/Time searches are only parsed into dates for command searches that
specify (`:`) or compare (`<`, `>`, `<=`, `>=`).

'Fuzzy' searching is not currently supported.

## Setup
The `CommandSearch.search` function takes a collection, a query, and an options hash.

Note: For MariaDB and Mysql5.x, please use the `CommandSearch.build`
[function](https://github.com/zumbalogy/command_search/blob/master/lib/command_search.rb)
with `:mysqlV5`.

**Collection:**
An array of hashes or a class connected to MongoDB, MySQL, SQLite, or PostgreSQL.

**Query:**
A string to used to search the collection.

**Options:**
A hash that has the keys `fields` and `aliases`.

 - fields:

   A hash that maps a field's name to a type. Valid types are `String`, `Boolean`, `Numeric`, and `Time`.

   Boolean fields will check for existence of a value if the underlying data is not actually a boolean.
   To query the `foo` field as both a timestamp and a boolean, a field can be configured like so:
   `foo: { type: Time, allow_existence_boolean: true }`.

    Fields to be searched across when no field is specified can be marked like so:
    `bar: { type: String, general_search: true }`

    A symbol can also be mapped to the symbol of another field as a simple alias.

 - aliases:

   An optional hash that maps strings or regexes to strings or procs.
   Parts of the query that match will be replaced by the string or the returned value of the proc.

   String keys are case insensitive, respect word boundaries, and skip quoted sections of the query.
   Query parts that specify their fields are also skipped, so `'foo' => 'bar'` will not effect the query `baz:foo`.

   Regex keys can match anything outside of quotations (and can explicitly match quotes).

   Procs are called once per match and are passed the matching value.
   Procs are free to have closures and side effects.

   A query can be altered before being passed to CommandSearch to sidestep any limitation.

   TIP: If aliasing to something complex, wrapping the output in parentheses can help it work as expected when combined with other syntax.

## Examples

An example setup for searching a Foo class in MongoDB:
```ruby
class Foo
  include Mongoid::Document
  field :title,       type: String
  field :description, type: String
  field :tags,        type: String
  field :child_id,    type: String
  field :feathers,    type: Integer
  field :cost,        type: Integer
  field :starred,     type: Boolean
  field :fav_date,    type: Time

  def self.search(query)
    options = {
      fields: {
        child_id: Boolean,
        title: { type: String, general_search: true },
        name: :title,
        description: { type: String, general_search: true },
        desc: :description,
        starred: Boolean,
        star: :starred,
        tags: { type: String, general_search: true },
        tag: :tags,
        feathers: { type: Numeric, allow_existence_boolean: true },
        cost: Numeric,
        fav_date: Time
      },
      aliases: {
        'favorite' => 'starred:true',
        'classic' => '(starred:true fav_date<15_years_ago)'
        /=/ => ':',
        'me' => -> () { current_user.name },
        /\$\d+/ => -> (match) { "cost:#{match[1..-1]}" }
      }
    }
    CommandSearch.search(Foo, query, options)
  end
end
```

An example setup of using aliases to allow users to choose how a list is sorted:
```ruby
class SortableFoo
  include Mongoid::Document
  field :foo, type: String
  field :bar, type: String

  def self.search(query)
    head_border = '(?<=^|\s|[|(-])'
    tail_border = '(?=$|\s|[|)])'
    sortable_field_names = ['foo', 'bar']
    sort_field = nil
    options = {
      fields: {
        foo: { type: String, general_search: true },
        bar: { type: String }
      },
      aliases: {
        /#{head_border}sort:\S+#{tail_border}/ => proc { |match|
          match_sort = match.sub(/^sort:/, '')
          sort_field = match_sort if sortable_field_names.include?(match_sort)
          ''
        }
      }
    }
    results = CommandSearch.search(SortableFoo, query, options)
    results = results.order_by(sort_field => :asc) if sort_field
    return results
  end
end
