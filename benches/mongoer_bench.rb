require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips do |bm|
  $bm = bm

  def bench(input, fields = nil, command_fields = nil)
    fields ||= [:title, :description, :tags]
    command_fields ||= { has_child_id: Boolean, title: String, name: :title }
    $bm.report(input.inspect.length) do
      aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
      lexed = CommandSearch::Lexer.lex(aliased)
      parsed = CommandSearch::Parser.parse!(lexed)
      dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_fields)
      cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, command_fields)
      opted = CommandSearch::Optimizer.optimize(cleaned)
      CommandSearch::Mongoer.build_query(opted, fields, command_fields)
    end
  end

  bench('', [], {})
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
