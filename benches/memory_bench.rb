require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

$hats = [
  { title: 'name name1 1' },
  { title: 'name name2 2', description: 'desk desk1 1' },
  { title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1' },
  { title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2' },
  { description: "desk new \n line" },
  { tags: "multi tag, 'quoted tag'" },
  { title: 'same_name', feathers: 2, cost: 0, fav_date: '2.months.ago' },
  { title: 'same_name', feathers: 5, cost: 4, fav_date: '1.year.ago' },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: '1.week.ago' },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: '1.week.ago' }
] * 100

Benchmark.ips() do |bm|
  $bm = bm

  def bench(input, fields = nil, command_fields = nil)
    fields ||= [:title, :description, :tags]
    command_fields ||= { has_child_id: Boolean, title: String, name: :title }
    $bm.report(input.inspect[0..99]) do
      ast = CommandSearch::Lexer.lex(input)
      CommandSearch::Parser.parse!(ast)
      CommandSearch::Optimizer.optimize!(ast)
      command_fields = CommandSearch::Normalizer.normalize!(ast, command_fields)
      $hats.select { |x| CommandSearch::Memory.check(x, ast, fields, command_fields) }.count
    end
  end

  bench('', [], {})
  bench('')
  bench('foo bar')
  bench('a b c d e')
  bench('-(a)|"b"')
  bench('name:foo tile -(foo bar)')
  bench('name:foo tile -(foo bar)|"hello world" foo>1.2')
  bench('name:foo tile a|a|a foo:bar -(foo bar)|"hello world" foo>1.2' * 1000)
  bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 1200)
end
