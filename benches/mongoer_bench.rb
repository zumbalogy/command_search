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
    $bm.report(input.inspect.length.to_s) do
      aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
      ast = CommandSearch::Lexer.lex(aliased)
      CommandSearch::Parser.parse!(ast)
      CommandSearch::Optimizer.optimize!(ast)
      CommandSearch::Normalizer.normalize!(ast, fields, true)
      CommandSearch::Mongoer.build_query(ast)
    end
  end

  bench('', {})
  bench('')
  bench('foo bar')
  bench('-(a)|"b"')
  bench('(price<=200 discount)|price<=99.99')
  bench('name:foo tile -(foo bar)')
  bench('name:foo tile -(foo bar)|"hello world" foo>1.2')
  bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 300)
  bench('()()()())(((((()())(()())))))(()()))))()())))(()((((())(()()(((((())()()()|||||()(HODF)_)))((((()||_())|||_()(*&^&(::sdfd' * 300)
  bench('s dfhjlds hlsdf hhh " sdf " a:b -4 -g sdjflh sdlkfhj lhdlfhl fdlfhldsfhg hsdljkjdfsld fhsdjklhhello "sdfdsfnj hklj" foo:556' * 300)
end
