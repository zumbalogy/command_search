# Command Search
[![CircleCI](https://circleci.com/gh/zumbalogy/command_search.svg?style=svg)](https://circleci.com/gh/zumbalogy/command_search)

A Ruby gem to help users query collections.

command_search should make it easy to create search inputs where
users can search for `flamingos` or `author:herbert`, as well
as using negations, comparisons, ors, and ands.

command_search also provides ways to alias keywords or regular expressions so that
the following substitutions are possible if desired:
* `name:alice` to `user_name:alice`
* `A+` to `grade>=97`
* `user:me` to `user:59guwJphUhqfd2A` (but with the actual ID)
* `hair=blue` to `hair:blue`

command_search does not require an engine, is relatively free of magic, and
should be easy to set up.

Feedback, questions, bug reports, pull requests, and feature requests are welcome.

## Syntax
Normal queries like `friday dinner`, `shoelace`, or `treehouse` work normally,
and will perform case insensitive partial matching per space-delineated part of
the query.
A user can specify full-word and case sensitive query parts by using quotation
marks, so the search `'ann'` will not match "anne" or `"bob"` to not match
"bobby". Quoted query parts can search for whole phrases, such as `"You had me at HELLO!"`.
Collections can also be queried with commands, which can be used in combination.

| Command | Character            | Examples                               |
| ----    | -----                | ----------                             |
| Specify | `:`                  | `attachment:true`, `grade:A`           |
| And     | `(...)`              | `(error important)`, `liked poked` (Note: space is an implicit and) |
| Or      | `\|`                 | `color\|colour`, `red\|orange\|yellow` |
| Compare | `<`, `>`, `<=`, `>=` | `created_at<monday`, `100<=pokes`      |
| Negate  | `-`                  | `-error`, `-(sat\|sun)`                |

## Limitations
Date/Time searches are only parsed into dates for command searches that
specify (`:`) or compare (`<`, `>`, `<=`, `>=`).

'Fuzzy' searching is not currently supported.

The only currently supported collections to query are
[MongoDB](https://github.com/mongodb/mongo) collections and in-memory arrays of
hashes.

SQL support hopefully coming soon.

## Dependencies
[Mongoid](https://github.com/mongodb/mongoid) is assumed if using command_search
to search MongoDB.

[Chronic](https://github.com/mojombo/chronic) is currently used to parse user
submitted dates, such as `tuesday` or `1/1/11`. Chronic's handling of timezones
and leap years and such is not perfect, but is only used if 'Date' is declared
as a field type in the config.

## Install
Command Line:
```ruby
gem install command_search
```
Gemfile:
```ruby
gem 'command_search'
```

## Setup

To query collections, command_search provides the CommandSearch.search function,
which takes a collection, a query, the general search fields and the command
search fields. Providing an empty list for either the general or command search
fields is OK.

* Collection: Either an array of hashes or a class that is a Mongoid::Document.

* Query: The string to use to search the collection, such as 'user:me' or 'bee|wasp'.

* Options: A hash that describes how to search the collection.
CommandSearch will use the following keys, all of which are optional:

  * fields: An array of the values to search in items of the collection.

  * command_fields: A hash that maps symbols matching a field's name
  to its type, or to another symbol as an alias. Valid types are `String`,
  `Boolean`, `Numeric`, and `Time`.
  Fields specified as `Boolean` will check for existence of a value if the
  underlying data is not actually a boolean, so, for example `bookmarked:true`
  could work even if the bookmarked field is a timestamp. To be able to query
  the bookmarked field as both a timestamp and a boolean, the symbol
  `:allow_existence_boolean` can be added to the value for the key bookmarked,
  like so: `bookmarked: [Time, :allow_existence_boolean]`.

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
  to sidestep any limitation.

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
      fields: [:title, :description, :tags],
      command_fields: {
        child_id: Boolean,
        title: String,
        name: :title,
        description: String,
        desc: :description,
        starred: Boolean,
        star: :starred,
        tags: String,
        tag: :tags,
        feathers: [Numeric, :allow_existence_boolean],
        cost: Numeric,
        fav_date: Time
      },
      aliases: {
        'favorite' => 'starred:true',
        /=/ => ':',
        'me' => -> () { current_user.name },
        /\$\d+/ => -> (match) { "cost:#{match[1..-1]}" }
      }
    }
    CommandSearch.search(Foo, query, options)
  end
end
```

## Examples

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
      fields: [:foo, :bar],
      command_fields: {},
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
```

## Internal Details

The lifecycle of a query is as follows: The query is alaised, lexed, parsed, de-aliased,
optimized, and then turned into a Ruby select function or a MongoDB compatible
query.

In the example shown below, the time it takes to turn the string
into a Mongo query is under a 0.2ms and smaller queries such
as "foo bar:baz" should take less than 70µs (2015 i7-6500U Ruby 2.2.2).

The lexer breaks a query into pieces.
```ruby
CommandSearch::Lexer.lex('(price<=200 discount)|price<=99.99')
[{ type: :paren,   value: '(' },
 { type: :str,     value: 'price' },
 { type: :compare, value: '<=' },
 { type: :number,  value: '200' },
 { type: :str,     value: 'discount' },
 { type: :paren,   value: ')' },
 { type: :pipe,    value: '|' },
 { type: :str,     value: 'price' },
 { type: :compare, value: '<' },
 { type: :number,  value: '99.99' }]
```
The parser then takes that and turns it into a tree.
```ruby
CommandSearch::Parser.parse!(_)
[{ type: :nest,
   nest_type: :pipe,
   nest_op: '|',
   value: [
     { type: :nest,
       nest_type: :paren,
       value: [{ type: :nest,
                 nest_type: :compare,
                 nest_op: '<=',
                 value: [{ type: :str, value: 'price' },
                         { type: :number, value: '200' }] },
               { type: :str, value: 'discount' }] },
    { type: :nest,
      nest_type: :compare,
      nest_op: '<',
      value: [{ type: :str, value: 'price' },
              { type: :number, value: '99.99' }] }] }]
```
It will then aliased to the names given in the command_fields, and command like
queries that don't match a specified command field will be turned into normal
string searches.

The optimizer will then tidy up some of the logic with rules such as:
* '-(a)' => '-a'
* '-(-a)' => 'a'
* 'a a' => 'a'
* 'a|a' => 'a'

It will then be turned into a Ruby function to be used in a select, or a mongo
compatible query.

```ruby
CommandSearch::Mongoer.build_query(_, [:name, :description], { price: Integer })
{ '$or' => [{ '$and' => [{ 'price' => { '$lte' => '200' } },
                         { '$or' => [{ name: /discount/i },
                                     { description: /discount/i }] }] },
            { 'price' => { '$lte' => '99.99' } }] }
```
