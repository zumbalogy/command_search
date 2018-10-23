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
  lex('foo')
  lex('foo bar')
  lex('abcedefhijklmnopqrstuvwxyz')
  lex('AbCeDeFhIjKlMnOpQrStUvWxYz')
  lex('abcedefhijklmnopqrstuvwxyz0123456789')
  lex('0123456789')
  lex('a b c e d e f h i j k l 3 4 5 6 7 8 9')
  lex('foo:bar apple|bannana cost<=100')
  lex('ab12' * 8)
  lex('ab12' * 10)
  lex('ab12' * 12)
  lex('ab1 ' * 12)
  # TODO: Needs some with quotes strings
end

__END__

user     system      total        real
Lex: ""                                                   0.014160   0.000007   0.014167 (  0.014187)
Lex: "foo"                                                0.045356   0.000106   0.045462 (  0.045582)
Lex: "foo bar"                                            0.087040   0.000174   0.087214 (  0.087276)
Lex: "abcedefhijklmnopqrstuvwxyz"                         0.327115   0.000400   0.327515 (  0.327917)
Lex: "AbCeDeFhIjKlMnOpQrStUvWxYz"                         0.319012   0.000274   0.319286 (  0.319522)
Lex: "abcedefhijklmnopqrstuvwxyz0123456789"               0.571238   0.000387   0.571625 (  0.571839)
Lex: "0123456789"                                         0.118445   0.000313   0.118758 (  0.119026)
Lex: "a b c e d e f h i j k l 3 4 5 6 7 8 9"              0.275065   0.000279   0.275344 (  0.275610)
Lex: "foo:bar apple|bannana cost<=100"                    0.410757   0.000251   0.411008 (  0.411129)
Lex: "ab12ab12ab12ab12ab12ab12ab12ab12"                   0.467645   0.000531   0.468176 (  0.468347)
Lex: "ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12"           0.635891   0.000377   0.636268 (  0.636482)
Lex: "ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12"   0.789148   0.000559   0.789707 (  0.790078)
Lex: "ab1 ab1 ab1 ab1 ab1 ab1 ab1 ab1 ab1 ab1 ab1 ab1 "   0.690651   0.000377   0.691028 (  0.691234)
