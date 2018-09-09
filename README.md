# Command Search
[![CircleCI](https://circleci.com/gh/zumbalogy/command_search.svg?style=svg)](https://circleci.com/gh/zumbalogy/command_search)

command_search is a Ruby gem to help users easily query collections.

command_search should make it a breeze to make gmail-style search bars, where
users can search for items that match `flamingos` or `author:herbert`, as well
as using negations, comparisons, ors, and ands.

command_search also provides ways to alias keywords so that the search
`name:alice` actually searches for `username:alice`, the search `A+` becomes
`grade>=97`, or `user:me` becomes `user:59guwJphUhqfd2A`, but with the actual
id of the current user.

command_search does not require an engine, is relatively free of magic, and
should be easy to set up.

## Syntax
Normal queries like `friday dinner`, `shoelace`, or `treehouse` work normally,
and will perform case insensitive partial matching per space-delineated part of
the query.
A user can specify full-word and case sensitive query parts by using quotation
marks, so the search `'ann'` will not match "anne" or `"bob"` to not match
"bobby". Quoted searches can match whole phrases, like `"You had me at HELLO!"`.
Collections can also be queried in a few extra ways, which can be used in
combination.

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

* Collection: Either an array of hashes or a class that is a
Mongoid::Document.

* Query: The string query to use to search the collection, such as
'user:me' or 'bee|wasp'.

* General search fields: An array of Ruby symbols that name the fields that will
be searched across when a field is not specified in a command.

* Command search fields: A Ruby hash that maps symbols matching a field's name
to its type, or to another symbol as an alias. Valid types are `String`,
`Boolean`, `Numeric`, and `Time`.
Fields specified as `Boolean` will check for existence of a value if the
underlying data is not actually a boolean, so, for example `bookmarked:true`
could work even if the bookmarked field is a timestamp. To be able to query
the bookmarked field as both a timestamp and a boolean, the symbol
`:allow_existence_boolean` can be added to the value for the key bookmarked,
like so: `bookmarked: [Time, :allow_existence_boolean]`.

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
    search_fields = [:title, :description, :tags]
    command_fields = {
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
    }
    CommandSearch.search(Foo, query, search_fields, command_fields)
  end
end
```

## Examples

## Internal Details

The lifecycle of a query is as follows: The query is lexed, parsed, de-aliased,
optimized, and then turned into a Ruby select function or a MongoDB compatible
query.

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
CommandSearch::Parser.parse(_)
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
                         { '$or' => [{ name: /discount/mi },
                                     { description: /discount/mi }] }] },
            { 'price' => { '$lte' => '99.99' } }] }
```
