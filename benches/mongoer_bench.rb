require('benchmark')

load(__dir__ + '/../lib/command_search/lexer.rb')
load(__dir__ + '/../lib/command_search/parser.rb')
load(__dir__ + '/../lib/command_search/command_dealiaser.rb')
load(__dir__ + '/../lib/command_search/optimizer.rb')
load(__dir__ + '/../lib/command_search/mongoer.rb')

class Boolean; end

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def mongo(input, fields, command_fields)
    title = "Mongo: #{input.inspect}"
    lexed = CommandSearch::Lexer.lex(input)
    parsed = CommandSearch::Parser.parse(lexed)
    dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_fields)
    cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, command_fields)
    opted = CommandSearch::Optimizer.optimize(cleaned)
    $bm.report(title) { $iterations.times { CommandSearch::Mongoer.build_query(opted, fields, command_fields) } }
  end

  fields = [:title, :description, :tags]
  command_fields = { has_child_id: Boolean, title: String, name: :title }
  mongo('', [], {})
  mongo('', fields, command_fields)
  mongo('foo bar', fields, command_fields)
  mongo('name:foo tile -(foo bar)', fields, command_fields)
  mongo('name:foo tile -(foo bar)|"hello world" foo>1.2', fields, command_fields)
  mongo('-(a)|"b"', fields, command_fields)
end
