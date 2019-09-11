require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

def bench(input, fields, command_fields)
  Benchmark.ips do |bm|

    bm.config(time: 2, warmup: 1)


    a = bm.report("Alias: #{input.inspect}") {
      $lexed = CommandSearch::Aliaser.alias(input, {'foo' => 'bar'})
    }
    # l = bm.report('L') {
    #   $lexed = CommandSearch::Lexer.lex(input)
    # }
    # p = bm.report('P') {
    #   $parsed = CommandSearch::Parser.parse!($lexed)
    # }
    # d = bm.report('D') {
    #   $dealiased = CommandSearch::CommandDealiaser.dealias($parsed, command_fields)
    # }
    # u = bm.report('U') {
    #   $cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable($dealiased, command_fields)
    # }
    # o = bm.report('O') {
    #   $opted = CommandSearch::Optimizer.optimize($cleaned)
    # }
    # m = bm.report('M') {
    #   CommandSearch::Mongoer.build_query($opted, fields, command_fields)
    # }
    # [l + p + d + u + o + m]
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
