require('ruby-prof')
require('mongoid')

load(__dir__ + '/../lib/command_search.rb')

class Hat
  include Mongoid::Document
end

RubyProf.measure_mode = RubyProf::WALL_TIME
# RubyProf.measure_mode = RubyProf::PROCESS_TIME
# RubyProf.measure_mode = RubyProf::ALLOCATIONS
# RubyProf.measure_mode = RubyProf::MEMORY

def run(input, fields = nil)
  fields ||= {
    has_child_id: Boolean,
    title: { type: String, general_search: true },
    tags: { type: String, general_search: true },
    description: { type: String, general_search: true },
    name: :title
  }
  CommandSearch.search(Hat, input, { fields: fields, aliases: { 'foo' => 'bar' } })
end

result = RubyProf.profile do
  1000.times do
    run('', {})
    run('')
    run('foo bar')
    run('-(a)|"b"')
    run('(price<=200 discount)|price<=99.99')
    run('name:foo tile -(foo bar)')
    run('name:foo tile -(foo bar)|"hello world" foo>1.2')
    run('name:foo tile a|a|a foo:bar -(foo bar)|"hello world" foo>1.2' * 50)
  end
  # run('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 1200)
end

# printer = RubyProf::GraphPrinter.new(result)
# printer = RubyProf::GraphHtmlPrinter.new(result)
printer = RubyProf::CallStackPrinter.new(result)

printer.print(STDOUT, min_percent: 0)

# File.open('profile_data.html', 'w') { |file| printer.print(file) }
