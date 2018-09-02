load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/../lib/parser.rb')
load(__dir__ + '/../lib/dealiaser.rb')
load(__dir__ + '/../lib/optimizer.rb')
load(__dir__ + '/../lib/mongoer.rb')
load(__dir__ + '/../lib/memory.rb')
load(__dir__ + '/../lib/searchable.rb')

require('rspec')
require('pry')

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

# require 'clipboard'
# def gen(x, y)
#   out = "q('#{x}', fields).should == #{q(x, y)}"
#   Clipboard.copy(out)
#   pp q(x, y)
#   out
# end
