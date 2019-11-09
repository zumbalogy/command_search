require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips() do |bm|
  $bm = bm

  def norm(input, fields)
    fields[:nnn] = { type: String, general_search: true }
    fields[:mmm] = { type: String, general_search: true }
    ast = CommandSearch::Lexer.lex(input)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize!(ast)
    $bm.report(input.inspect) {
      ast2 = Marshal.load(Marshal.dump(ast))
      CommandSearch::Normalizer.normalize!(ast2, fields)
    }
  end

  norm('', {})
  norm('foo:bar', { foo: String })
  norm('foo:bar', { foo: :abc, abc: String })
  norm('foo:bar ' * 10, { foo: String })
  norm('foo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  norm('fo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  norm('fo:bar ' * 10, { })
  norm('fo:bar a:a b:b c:c ' * 1, { })
  norm('fo:bar a:a b:b c:c ' * 2, { })
  norm('fo:bar a:a b:b c:c ' * 4, { })
end
