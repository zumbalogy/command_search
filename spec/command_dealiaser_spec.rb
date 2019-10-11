load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::CommandDealiaser do

  def parse(x)
    tokens = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(tokens)
  end

  def dealias(x, aliases)
    dealiased = CommandSearch::CommandDealiaser.dealias(parse(x), aliases)
    CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, aliases)
  end

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
    dealias('-foo:bar', {})[0][:value].should == [{type: :str, value: 'foo:bar'}]
    dealias('-foo:bar|baz', {})[0][:value][0][:value].should == [{type: :str, value: 'foo:bar'}]
  end

  it 'should cast booleans' do
    def c(x)
      aliases = { a: :foo, foo: Boolean, b: [Numeric, :allow_existence_boolean] }
      dealias(x, aliases)
    end
    c('a:true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: true}]}
    ]
    c('a:false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}
    ]
    c('a:foo').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}
    ]
    c('-a:true')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: true}]}
    ]
    c('a:-true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}
    ]
    c('a:-false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}
    ]
    c('b:true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: true}]}
    ]
    c('b:false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: false}]}
    ]
    c('-b:true')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: true}]}
    ]
    c('-b:false')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: false}]}
    ]
    c('b:-true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: '-true'}]}
    ]
    c('b:-false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: '-false'}]}
    ]
    c('b:"false"').should == c("b:'false'")
    c('b:"true"').should == c("b:'true'")
    c('b:"false"').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :quoted_str, value: 'false'}]}
    ]
    c('b:"true"').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :quoted_str, value: 'true'}]}
    ]
    c('b:foo').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: 'foo'}]}
    ]
    c('c:true').should == [{type: :str, value: 'c:true'}]
    c('c:false').should == [{type: :str, value: 'c:false'}]
    c('-c:true')[0][:value].should == [{type: :str, value: 'c:true'}]
    c('-c:false')[0][:value].should == [{type: :str, value: 'c:false'}]
    c('c:-true').should == [{type: :str, value: 'c:-true'}]
    c('c:-false').should == [{type: :str, value: 'c:-false'}]
  end
end
