load(__dir__ + '/../lib/command_search.rb')

require('rspec')
require('pry')
require('coderay')

def pp(input)
  str = PP.pp(input, '')
  puts CodeRay.scan(str, :ruby).terminal
  puts
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end
