require('benchmark')

load(__dir__ + '/../lib/command_search.rb')

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def optimize(input)
    title = "Optimize: #{input.inspect}"
    lexed = CommandSearch::Lexer.lex(input)
    parsed = CommandSearch::Parser.parse!(lexed)
    $bm.report(title) { $iterations.times { CommandSearch::Optimizer.optimize(parsed) } }
  end

  optimize('')
  optimize(' -(a|a|b|c)')
  optimize(' -(a|a|b|c)' * 2)
  optimize(' -(a|a|b|c)' * 4)
  optimize(' -(a|a|b|c)' * 8)
end
