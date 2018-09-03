load(__dir__ + '/../lib/command_search.rb')

require('rspec')
require('pry')

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end
