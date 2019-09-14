require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

class Boolean; end

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
    lexed = nil
    parsed = nil
    dealiased = nil
    cleaned = nil
    opted = nil
    query = nil
    $bm.report(input.inspect) { lexed = CommandSearch::Lexer.lex(input) }
    $bm.report('p')           { parsed = CommandSearch::Parser.parse!(lexed) }
    $bm.report('d')           { dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_fields) }
    $bm.report('c')           { cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, command_fields) }
    $bm.report('o')           { opted = CommandSearch::Optimizer.optimize(cleaned) }
    $bm.report('q')           { query = CommandSearch::Memory.build_query(opted, fields, command_fields) }
    $bm.report('_____select') { $hats.select(&query).count }
  end

  bench('', [], {})
  bench('')
  bench('foo bar')
  bench('-(a)|"b"')
  bench('name:foo tile -(foo bar)')
  bench('name:foo tile -(foo bar)|"hello world" foo>1.2')
end
