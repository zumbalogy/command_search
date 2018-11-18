require('benchmark')

load(__dir__ + '/../lib/command_search/lexer.rb')
load(__dir__ + '/../lib/command_search/parser.rb')

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def parse(input)
    title = "Parse: #{input.inspect}"
    lexed = CommandSearch::Lexer.lex(input)
    $bm.report(title) { $iterations.times { CommandSearch::Parser.parse!(lexed) } }
  end

  parse('')
  parse('foo bar')
  parse('-("hello world"|goodbye(-a|b|b|-c))')
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 2)
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 3)
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 4)
  parse('-("hello world"|goodbye(-a|b|b|-c)(' * 4)
end
