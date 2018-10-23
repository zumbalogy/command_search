require('benchmark')

load(__dir__ + '/../lib/command_search/lexer.rb')

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def lex(input)
    title = "Lex: #{input.inspect}"
    $bm.report(title) { $iterations.times { CommandSearch::Lexer.lex(input) } }
  end

  lex('')
  # lex('foo')
  lex('foo bar')
  lex('abcedefhijklmnopqrstuvwxyz')
  # lex('AbCeDeFhIjKlMnOpQrStUvWxYz')
  lex('abcedefhijklmnopqrstuvwxyz0123456789')
  lex('0123456789')
  lex('a b c e d e f h i j k l 3 4 5 6 7 8 9')
  lex('foo:bar apple|bannana cost<=100')
  # lex('ab12' * 8)
  lex('ab12' * 10)
  # lex('ab12' * 12)
  lex('ab1 ' * 12)
  lex('"foo" \'ba\'' * 8)
  lex('"foo" \'ba\'' * 10)
  lex('"fo" \'ba\'' * 12)
end

__END__

Lex: "\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'"
0.707551   0.003829   0.711380 (  0.715947)
Lex: "\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'\"foo\" 'ba'"
0.947813   0.003143   0.950956 (  0.954802)
Lex: "\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'\"fo\" 'ba'"
1.162016   0.004802   1.166818 (  1.172862)
