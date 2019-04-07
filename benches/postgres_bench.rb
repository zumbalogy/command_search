require('benchmark')
require('active_record')
require('pg')

include Benchmark

load(__dir__ + '/../lib/command_search.rb')

db_config = YAML.load_file(__dir__ + '/../spec/assets/postgres.yml')
ActiveRecord::Base.remove_connection
ActiveRecord::Base.establish_connection(db_config['test'])

ActiveRecord::Schema.define do
  create_table :hats, force: true do |t|
    t.string :title
    t.string :description
    t.string :state
    t.string :tags
    t.boolean :starred
    t.string :child_id
    t.integer :feathers
    t.integer :feathers2
    t.integer :cost
    t.datetime :fav_date
    t.datetime :fav_date2
  end

  create_table(:bat1s, force: true) { |t| t.date :fav_date }
  create_table(:bat2s, force: true) { |t| t.datetime :fav_date }
end

class Hat < ActiveRecord::Base
end

$iterations = 1000

def bench(input, fields, command_fields)
  Benchmark.benchmark(CAPTION, 60, FORMAT, 'Total:') do |bm|
    a = bm.report("Alias: #{input.inspect}") { $iterations.times {
      $lexed = CommandSearch::Aliaser.alias(input, {'foo' => 'bar'})
    }}
    l = bm.report('L') { $iterations.times {
      $lexed = CommandSearch::Lexer.lex(input)
    }}
    p = bm.report('P') { $iterations.times {
      $parsed = CommandSearch::Parser.parse!($lexed)
    }}
    d = bm.report('D') { $iterations.times {
      $dealiased = CommandSearch::CommandDealiaser.dealias($parsed, command_fields)
    }}
    u = bm.report('U') { $iterations.times {
      $cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable($dealiased, command_fields)
    }}
    o = bm.report('O') { $iterations.times {
      $opted = CommandSearch::Optimizer.optimize($cleaned)
    }}
    m = bm.report('PG') { $iterations.times {
      CommandSearch::ActiveRecordPostgres.search(Hat, $opted, fields, command_fields)
    }}
    [l + p + d + u + o + m]
  end
end

fields = [:title, :description, :tags]
command_fields = { has_child_id: Boolean, title: String, name: :title }

bench('', [], {})
bench('', fields, command_fields)
bench('foo bar', fields, command_fields)
bench('-(a)|"b"', fields, command_fields)
bench('(price<=200 discount)|price<=99.99', fields, command_fields)
bench('name:foo tile -(foo bar)', fields, command_fields)
bench('name:foo tile -(foo bar)|"hello world" foo>1.2', fields, command_fields)
