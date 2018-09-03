load(__dir__ + '/../lib/command_search.rb')

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
