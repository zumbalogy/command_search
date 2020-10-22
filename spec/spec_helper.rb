load(__dir__ + '/../lib/command_search.rb')

require('rspec')

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

begin
  require('coderay')
  require('pry-byebug')
  require('binding_of_caller')
  require('simplecov')

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

  SimpleCov.start do
    add_filter "spec/"
  end

rescue LoadError => e
  puts "Gem Loading Failed: #{e}"
end
