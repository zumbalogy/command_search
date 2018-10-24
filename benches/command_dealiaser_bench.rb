require('benchmark')

load(__dir__ + '/../lib/command_search/lexer.rb')
load(__dir__ + '/../lib/command_search/parser.rb')
load(__dir__ + '/../lib/command_search/command_dealiaser.rb')

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def dealias(input, command_fields)
    title = "Dealias: #{input.inspect}"
    lexed = CommandSearch::Lexer.lex(input)
    parsed = CommandSearch::Parser.parse(lexed)
    $bm.report(title) { $iterations.times { CommandSearch::CommandDealiaser.dealias(parsed, command_fields) } }
  end

  dealias('', {})
  dealias('foo:bar', { foo: String })
  dealias('foo:bar', { foo: :abc, abc: String })
  dealias('foo:bar ' * 10, { foo: String })
  dealias('foo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  dealias('fo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  dealias('fo:bar ' * 10, { })
end
