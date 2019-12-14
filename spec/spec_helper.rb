load(__dir__ + '/../lib/command_search.rb')

require('rspec')
require('coderay')
require('pry-byebug')
require('binding_of_caller')

require('active_record')
require('pg')
require('mongoid')

Mongoid.load!(__dir__ + '/assets/mongoid.yml', :test)

db_config = YAML.load_file(__dir__ + '/assets/postgres.yml')
ActiveRecord::Base.remove_connection
ActiveRecord::Base.establish_connection(db_config['test'])

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
