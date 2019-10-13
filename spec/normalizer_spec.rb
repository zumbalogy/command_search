load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Normalizer do

  def parse(x)
    ast = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize(ast)
    ast
  end

  def dealias(x, aliases)
    ast = parse(x)
    CommandSearch::Normalizer.normalize!(ast, aliases)
    ast
  end

  # it 'should cast regular expressions' do
  #   # TODO
  # end

  # it 'should cast dates' do
  #   # TODO
  # end

  it 'should handle aliased commands and compares' do
    aliases = { f00: :foo, foo: String, gray: :grey, grey: Numeric }
    # TODO: write tests so that maybe casting and dealiasing are done seperate and all

    # dealias('f00 f00:bar', aliases).should == parse('f00 foo:bar')
    # dealias('gray:0', aliases).should == parse('grey:0')
    # dealias('gray<=1 grey>=-1', aliases).should == parse('grey<=1 grey>=-1')

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
    dealias('a:b', {}).should == [{ type: :str, value: /a:b/i }]
    dealias('-foo:bar', {})[0][:value].should == [{type: :str, value: /foo:bar/i }]
    dealias('-foo:bar|baz', {})[0][:value][0][:value].should == [{type: :str, value: /foo:bar/i }]
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
    c('c:true').should == [{type: :str, value: /c:true/i}]
    c('c:false').should == [{type: :str, value: /c:false/i}]
    c('-c:true')[0][:value].should == [{type: :str, value: /c:true/i}]
    c('-c:false')[0][:value].should == [{type: :str, value: /c:false/i}]
    c('c:-true').should == [{type: :str, value: /c:\-true/i}]
    c('c:-false').should == [{type: :str, value: /c:\-false/i}]
  end
end
