load(__dir__ + '/./spec_helper.rb')

def parse(x)
  tokens = Lexer.lex(x)
  Parser.parse(tokens)
end

def dealias(x, aliases)
  Dealiaser.dealias(parse(x), aliases)
end

describe Dealiaser do

  it 'should not change general searches or unaliased commands' do
    aliases = { f00: :foo, foo: String, gray: :grey, grey: Numeric }
    dealias('f00 grey:100', aliases).should == parse('f00 grey:100')
    dealias('f00 foo:bar', aliases).should == parse('f00 foo:bar')
  end

  it 'should handle aliased commands and compares' do
    aliases = { f00: :foo, foo: String, gray: :grey, grey: Numeric }
    dealias('f00 f00:bar', aliases).should == parse('f00 foo:bar')
    dealias('gray:0', aliases).should == parse('grey:0')
    dealias('gray<=1 grey>=-1', aliases).should == parse('grey<=1 grey>=-1')

    aliases2 = { foo: :bar, bar: Numeric }
    dealias('foo<100', aliases2).should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: "bar"},
               {type: :number, value: "100"}]}]
  end

  # it 'should wacky inputs' do
  # end
end
