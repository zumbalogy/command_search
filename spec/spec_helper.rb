load(__dir__ + '/../lib/command_search.rb')

require('rspec')
require('pry')

require('timeout')

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }

  # if ENV['MUTANT']
  # config.around(:each) do |example|
  #   Timeout.timeout(5, &example)
  # end
end
