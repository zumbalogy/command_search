require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips do |bm|
  $bm = bm

  def bench(input, fields = nil)
    fields ||= {
      has_child_id: Boolean,
      title: { type: String, general_search: true },
      description: { type: String, general_search: true },
      tags: { type: String, general_search: true },
      name: :title
    }
    # $bm.report(input.inspect.length.to_s + '  a') do
    #   aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
    # end
    $bm.report(input.inspect.length.to_s + '  l') do
      aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
      ast = CommandSearch::Lexer.lex(aliased)
    end
    $bm.report(input.inspect.length.to_s + '  p') do
      aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
      ast = CommandSearch::Lexer.lex(aliased)
      CommandSearch::Parser.parse!(ast)
    end
    # $bm.report(input.inspect.length.to_s + '  o') do
    #   aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
    #   ast = CommandSearch::Lexer.lex(aliased)
    #   CommandSearch::Parser.parse!(ast)
    #   CommandSearch::Optimizer.optimize!(ast)
    # end
    # $bm.report(input.inspect.length.to_s + '  n') do
    #   aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
    #   ast = CommandSearch::Lexer.lex(aliased)
    #   CommandSearch::Parser.parse!(ast)
    #   CommandSearch::Optimizer.optimize!(ast)
    #   CommandSearch::Normalizer.normalize!(ast, fields)
    # end
    # $bm.report(input.inspect.length.to_s + '  m') do
    #   aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
    #   ast = CommandSearch::Lexer.lex(aliased)
    #   CommandSearch::Parser.parse!(ast)
    #   CommandSearch::Optimizer.optimize!(ast)
    #   CommandSearch::Normalizer.normalize!(ast, fields)
    #   CommandSearch::Mongoer.build_query(ast)
    # end
    $bm.compare!
  end

  # bench('', {})
  # bench('')
  # bench('foo bar')
  # bench('-(a)|"b"')
  # bench('(price<=200 discount)|price<=99.99')
  # bench('name:foo tile -(foo bar)')
  bench('name:foo tile -(foo bar)|"hello world" foo>1.2')
  #
  # bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 300)
  # bench('()()()())(((((()())(()())))))(()()))))()())))(()((((())(()()(((((())()()()|||||()(HODF)_)))((((()||_())|||_()(*&^&(::sdfd' * 300)
  # bench('s dfhjlds hlsdf hhh " sdf " a:b -4 -g sdjflh sdlkfhj lhdlfhl fdlfhldsfhg hsdljkjdfsld fhsdjklhhello "sdfdsfnj hklj" foo:556' * 300)
end

=begin

Calculating -------------------------------------
                   9    125.516k (± 1.0%) i/s -    635.040k in   5.059945s
                  36    183.476k (± 0.7%) i/s -    932.634k in   5.083416s

Calculating -------------------------------------
                   9     82.529k (± 0.8%) i/s -    418.912k in   5.076257s
                  36     42.654k (± 1.2%) i/s -    217.256k in   5.094148s

Calculating -------------------------------------
                   9     60.423k (± 1.2%) i/s -    307.400k in   5.088189s
                  36     24.768k (± 1.4%) i/s -    123.930k in   5.004650s

Calculating -------------------------------------
                   9     50.010k (± 1.2%) i/s -    254.228k in   5.084291s
                  36     19.790k (± 1.1%) i/s -     99.093k in   5.007878s

Calculating -------------------------------------
                   9     27.568k (± 1.0%) i/s -    140.301k in   5.089710s
                  36      9.983k (± 0.8%) i/s -     50.082k in   5.017202s

Calculating -------------------------------------
                   9     25.083k (± 1.8%) i/s -    126.880k in   5.060120s
                  36      9.145k (± 2.6%) i/s -     46.000k in   5.033543s
=end
