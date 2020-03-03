# Command Search
[![CircleCI](https://circleci.com/gh/zumbalogy/command_search.svg?style=svg)](https://circleci.com/gh/zumbalogy/command_search)
[![Gem Version](https://badge.fury.io/rb/command_search.svg)](https://badge.fury.io/rb/command_search)
[![Downloads](https://img.shields.io/gem/dt/command_search.svg?style=flat)](https://rubygems.org/gems/command_search)

**command_search** is a Ruby gem to help users query collections.

It works with
[PostgreSQL](https://www.postgresql.org/),
[MySQL](https://www.mysql.com/),
[SQLite](https://www.sqlite.org/),
[MongoDB](https://www.mongodb.com/),
and arrays of hashes.

It provides basic search functionality as well as as quotation, negation, comparison, or, and and logic, so users can search for `flamingos` or `author:herbert` or `price<200 discount`.

command_search makes it easy to add syntax and macros for users.
The query `A+` could be handled as `grade>=95`.
Some examples:
* `$99` --> `price:99`
* `starred` --> `liked_at:true` (can match a non-nil value)
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
command_search provides 

To query collections, command_search provides the CommandSearch.search function,
which takes a collection, a query, and an options hash.

* Collection: Either an array of hashes or a class that is a Mongoid::Document.

* Query: The string to use to search the collection, such as 'user:me' or 'bee|wasp'.

* Options: A hash that describes how to search the collection.

  * fields: A hash that maps symbols matching a field's name
  to its type, another symbol as an alias, or a hash. Valid types are `String`,
  `Boolean`, `Numeric`, and `Time`.
  Fields to be searched though when no field is specified in the query should be
  marked like so: `description: { type: String, general_search: true }`
  `Boolean` fields will check for existence of a value if the underlying
  data is not actually a boolean, so the query `bookmarked:true` could work even
  if the bookmarked field is a timestamp. To be able to query the bookmarked
  field as both a timestamp and a boolean, a symbol can be added to the value
  in the hash like so: `bookmarked: { type: Time, allow_existence_boolean: true }`.

  * aliases: A hash that maps strings or regex to strings or procs.
  CommandSearch will iterate though the hash and substitute parts of the query
  that match the key with the value or the returned value of the proc. The procs
  will be called once per match with the value of the match and are free to have
  closures and side effects.
  This happens before any other parsing or searching steps.
  Keys that are strings will be converted into a regex that is case insensitive,
  respects word boundaries, and does not alias quoted sections of the query. Note
  that, for aliasing purposes, specifying and comparing query parts are treated as
  whole words, so `'foo' => 'bar'` will not effect the query `baz:foo`.
  Regex keys will be used as is, but respect user quotations unless the regex
  matches the quotes. A query can be altered before being passed to CommandSearch
  to sidestep any limitation. NOTE: If aliasing to something complex, wrapping the
  output in parentheses can help it work as expected with the command_search syntax.

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
