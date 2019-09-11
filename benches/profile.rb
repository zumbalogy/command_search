require 'ruby-prof'

load(__dir__ + '/../lib/command_search.rb')

# RubyProf.measure_mode = RubyProf::WALL_TIME
# RubyProf.measure_mode = RubyProf::PROCESS_TIME
# RubyProf.measure_mode = RubyProf::ALLOCATIONS
# RubyProf.measure_mode = RubyProf::MEMORY

def bench(input, fields = nil, command_fields = nil)
  fields ||= [:title, :description, :tags]
  command_fields ||= { has_child_id: Boolean, title: String, name: :title }
  lexed = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
  lexed = CommandSearch::Lexer.lex(input)
  parsed = CommandSearch::Parser.parse!(lexed)
  dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_fields)
  cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, command_fields)
  opted = CommandSearch::Optimizer.optimize(cleaned)
  CommandSearch::Mongoer.build_query(opted, fields, command_fields)
end

result = RubyProf.profile do
  1000.times do
    bench('', [], {})
    bench('')
    bench('foo bar')
    bench('-(a)|"b"')
    bench('(price<=200 discount)|price<=99.99')
    bench('name:foo tile -(foo bar)')
    bench('name:foo tile -(foo bar)|"hello world" foo>1.2')
  end
end

printer = RubyProf::GraphPrinter.new(result)
# printer = RubyProf::GraphHtmlPrinter.new(result)
# printer = RubyProf::CallStackPrinter.new(result)

printer.print(STDOUT, min_percent: 5)

# File.open('tmp/profile_data.html', 'w') { |file| printer.print(file) }
