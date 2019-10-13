require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips() do |bm|
  $bm = bm

  def parse(input)
    title = input.length
    ast = CommandSearch::Lexer.lex(input)
    $bm.report(title) { CommandSearch::Parser.parse!(ast) }
  end

  parse('')
  parse('foo bar')
  parse('-("hello world"|goodbye(-a|b|b|-c))')
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 2)
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 4)
  parse('-("hello world"|goodbye(-a|b|b|-c))' * 16)
  parse('-("hello world"|goodbye(-a|b|b|-c)(' * 16)
end
