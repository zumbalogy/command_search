load(__dir__ + '/../lib/command_search.rb')

require('rspec')
require('coderay')
require('pry-byebug')
require('binding_of_caller')

require('mongoid')

require('active_record')
require('sqlite3')
require('mysql2')
require('pg')

Mongoid.load!(__dir__ + '/assets/mongoid.yml', :test)

def pp(*inputs)
  puts
  inputs.each do |input|
    str = PP.pp(input, '')
    puts CodeRay.scan(str, :ruby).terminal
    puts
  end
end

def bb
  Pry.start(binding.of_caller(1))
end

alias :debug :bb
alias :debugger :bb

Pry.commands.alias_command('bb', 'disable-pry')
Pry.commands.alias_command('kill', 'disable-pry')

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end
