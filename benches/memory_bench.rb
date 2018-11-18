require('benchmark')

include Benchmark

load(__dir__ + '/../lib/command_search/lexer.rb')
load(__dir__ + '/../lib/command_search/parser.rb')
load(__dir__ + '/../lib/command_search/command_dealiaser.rb')
load(__dir__ + '/../lib/command_search/optimizer.rb')
load(__dir__ + '/../lib/command_search/memory.rb')

class Boolean; end

$iterations = 1000

$hats = [
  { title: 'name name1 1' },
  { title: 'name name2 2', description: 'desk desk1 1' },
  { title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1' },
  { title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2' },
  { description: "desk new \n line" },
  { tags: "multi tag, 'quoted tag'" },
  { title: 'same_name', feathers: 2, cost: 0, fav_date: '2.months.ago' },
  { title: 'same_name', feathers: 5, cost: 4, fav_date: '1.year.ago' },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: '1.week.ago' }
]

def mem(input, fields, command_fields)
  Benchmark.benchmark(CAPTION, 60, FORMAT, 'Total:') do |bm|
    l = bm.report("Lex: #{input.inspect}") { $iterations.times {
      $lexed = CommandSearch::Lexer.lex(input)
    }}
    $parsed = CommandSearch::Parser.parse!($lexed)
    $dealiased = CommandSearch::CommandDealiaser.dealias($parsed, command_fields)
    $cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable($dealiased, command_fields)
    $opted = CommandSearch::Optimizer.optimize($cleaned)
    m = bm.report('M') { $iterations.times {
      $query = CommandSearch::Memory.build_query($opted, fields, command_fields)
    }}
    q = bm.report('Q') { $iterations.times {
      $hats.select(&$query).count
    }}
    [l + m + q]
  end
end

fields = [:title, :description, :tags]
command_fields = { has_child_id: Boolean, title: String, name: :title }

mem('', [], {})
mem('', fields, command_fields)
mem('foo bar', fields, command_fields)
mem('-(a)|"b"', fields, command_fields)
mem('name:foo tile -(foo bar)', fields, command_fields)
mem('name:foo tile -(foo bar)|"hello world" foo>1.2', fields, command_fields)
