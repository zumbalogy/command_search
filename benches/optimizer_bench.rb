require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips() do |bm|
  $bm = bm

  def optimize(input)
    title = "Optimize #{input.length}: #{input.inspect[0..24]}"
    lexed = CommandSearch::Lexer.lex(input)
    parsed = CommandSearch::Parser.parse!(lexed)
    $bm.report(title) { CommandSearch::Optimizer.optimize(parsed) }
  end

  optimize('')
  optimize('a|b|(a|b|c)|')
  optimize('a|a a|b|(a|b|c)|')
  optimize('a (b c) a|a a|b|(a|b|c)|')
  optimize('(((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|')
  optimize('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|')
  optimize('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 10)
  optimize('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 100)
  optimize('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 500)
end


# TODO: test some really long strings into the system (like 50k characters) to see when it breaks and all)
# and then maybe cap the inputs, and put a note in the readme saying theres a cap but users might want to cap it further
