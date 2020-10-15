require 'simplecov'

SimpleCov.start do
  add_filter "spec/"
end

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

unless ENV['MONGOID_CONFIGURED']
  ENV['MONGOID_CONFIGURED'] = 'true'
  Mongoid.configure do |config|
    host = ENV.fetch("MONGODB_HOST") { 'localhost' }
    port = ENV.fetch("MONGODB_PORT") { '27017' }
    config.clients.default = {
      hosts: ["#{host}:#{port}"],
      database: 'mongoid_test'
    }
  end
  Mongo::Logger.logger.level = Logger::FATAL
end

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
