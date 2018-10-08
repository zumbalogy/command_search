load(__dir__ + '/./spec_helper.rb')

def parse(x)
  tokens = CommandSearch::Lexer.lex(x)
  CommandSearch::Parser.parse(tokens)
end

def dealias(x, aliases)
  dealiased = CommandSearch::CommandDealiaser.dealias(parse(x), aliases)
  CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, aliases)
end

describe CommandSearch::CommandDealiaser do

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
       value: [{type: :str, value: 'bar'},
               {type: :number, value: '100'}]}]
  end

  it 'should set unaliased commands to normal searches' do
    dealias('foo foo:bar', {}).should_not == parse('foo foo:bar')
    dealias('a:b', {}).should == [{ type: :str, value: 'a:b' }]
  end

end
