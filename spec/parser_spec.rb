load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/../lib/parser.rb')
require('rspec')
require('pry')

# break this into a spec helper maybe
RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

def parse(x)
  tokens= Lexer.lex(x)
  Parser.parse(tokens)
end

require 'clipboard'
def gen(x)
  out = "parse('#{x}').should == #{parse(x)}"
  Clipboard.copy(out)
  out
end

describe Parser do
  it 'should be able to split basic parts on spaces' do
    parse('foo').should == [{:type=>:str, :value=>"foo"}]
    parse('f1oo').should == [{:type=>:str, :value=>"f1oo"}]
    # sp('f1oo').should == ['f1oo']
    # sp('a b 1 foo').should == ['a', 'b', '1', 'foo']
    # sp('1 1 1').should == ['1', '1', '1']
    # sp('1 2 3').should == ['1', '2', '3']
  end

  # it 'should handle OR statements' do
  #   sp('a|b').flatten.should == ['a', '|', 'b']
  #   sp('a|b c|d').should == [['a', '|', 'b'], ['c', '|', 'd']]
  #   sp('a|b|c').should == [['a', '|', 'b', '|', 'c']]
  # end

  # it 'should handle negating' do
  #   sp('-a').should == [['-', 'a']]
  #   sp('-foo -bar').should == [['-', 'foo'], ['-', 'bar']]
  #   sp('ab-cd').should == ['ab-cd']
  # end

  # it 'should handle commands' do
  #   sp('foo:bar').should == ['foo:bar']
  #   sp('foo:bar a:b c').should == ['foo:bar', 'a:b', 'c']
  #   sp('1:2').should == ["1:2"]
  # end

  # it 'should handle comparisons' do
  #   sp('red>5').should == ["red>5"]
  #   sp('blue<=green').should == ["blue<=green"]
  #   sp('a<b b>=-1').should == ["a<b", "b>=-1"]
  #   # sp('1<5<10').should == ["1<5<10"]
  # end

  # # it 'should handle negative numbers' do
  # #   pending
  # #   sp('-5').should_not == [["-", "5"]]
  # # end

  # it 'should handle quotes' do
  #   sp("'-5'").should == ["'-5'"]
  #   sp("a 'foo bar' b").should == ["a", "'foo bar'", "b"]
  # end

  # it 'should handle parens' do
  #   sp('(a)').should == [["a"]]
  #   sp('(a foo)').should == [["a", "foo"]]
  #   sp('a (foo bar) b').should == ["a", ["foo", "bar"], "b"]
  # end

  # it 'should handle nested parens' do
  # end

  # it 'should handle OR and NOT with parens' do
  # end

  # it 'should handle wacky combinations' do
  # end

end
