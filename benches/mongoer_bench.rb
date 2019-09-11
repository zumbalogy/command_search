require('benchmark')

include Benchmark

load(__dir__ + '/../lib/command_search.rb')

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
    m = bm.report('M') { $iterations.times {
      CommandSearch::Mongoer.build_query($opted, fields, command_fields)
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
