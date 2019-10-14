load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Normalizer do

  def parse(x)
    ast = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize!(ast)
    ast
  end

  def norm(x, aliases)
    ast = parse(x)
    CommandSearch::Normalizer.normalize!(ast, aliases)
    ast
  end

  it 'should handle aliased commands and compares' do
    aliases = { foo: :bar, bar: Numeric }
    norm('foo<100', aliases).should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: 'bar'},
               {type: :number, value: '100'}]}]
  end

  it 'should set unaliased commands to normal searches' do
    norm('foo foo:bar', {}).should_not == parse('foo foo:bar')
    norm('a:b', {}).should == [{ type: :str, value: /a:b/i }]
    norm('-foo:bar', {})[0][:value].should == [{type: :str, value: /foo:bar/i }]
    norm('-foo:bar|baz', {})[0][:value][0][:value].should == [{type: :str, value: /foo:bar/i }]
  end

  it 'should cast booleans' do
    def c(x)
      aliases = { a: :foo, foo: Boolean, b: [Numeric, :allow_existence_boolean] }
      norm(x, aliases)
    end
    c('a:true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: true}]}]
    c('a:false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}]
    c('a:foo').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}]
    c('-a:true')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: true}]}]
    c('a:-true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}]
    c('a:-false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'foo'}, {type: Boolean, value: false}]}]
    c('b:true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: true}]}]
    c('b:false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: false}]}]
    c('-b:true')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: true}]}]
    c('-b:false')[0][:value].should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :existence, value: false}]}]
    c('b:-true').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: '-true'}]}]
    c('b:-false').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: '-false'}]}]
    c('b:"false"').should == c("b:'false'")
    c('b:"true"').should == c("b:'true'")
    c('b:"false"').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :quoted_str, value: 'false'}]}]
    c('b:"true"').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :quoted_str, value: 'true'}]}]
    c('b:foo').should == [{
      type: :nest,
      nest_type: :colon,
      nest_op: ':',
      value: [{type: :str, value: 'b'}, {type: :str, value: 'foo'}]}]
    c('c:true').should == [{type: :str, value: /c:true/i}]
    c('c:false').should == [{type: :str, value: /c:false/i}]
    c('-c:true')[0][:value].should == [{type: :str, value: /c:true/i}]
    c('-c:false')[0][:value].should == [{type: :str, value: /c:false/i}]
    c('c:-true').should == [{type: :str, value: /c:\-true/i}]
    c('c:-false').should == [{type: :str, value: /c:\-false/i}]
  end

  it 'should cast regular expressions' do
    aliases = { s: String, n: Integer }
    norm('', aliases).should == []
    norm('foo', aliases).should == [{type: :str, value: /foo/i}]
    norm('foo 5', aliases).should == [{type: :str, value: /foo/i}, {number_value: '5', type: :number, value: /5/i}]
    norm('-(foo|-bar)|3', aliases).should == [
      {nest_op: '|',
       nest_type: :pipe,
       type: :nest,
       value:
        [{nest_op: '-',
          nest_type: :minus,
          type: :nest,
          value:
           [{nest_op: '|',
             nest_type: :pipe,
             type: :nest,
             value:
              [{type: :str, value: /foo/i},
               {nest_op: '-',
                nest_type: :minus,
                type: :nest,
                value: [{type: :str, value: /bar/i}]}]}]},
         {number_value: '3', type: :number, value: /3/i}]}]
     norm('s:-2', aliases).should ==  [
       {nest_op: ':',
        nest_type: :colon,
        type: :nest,
        value: [{type: :str, value: 's'}, {type: :number, value: /\-2/i}]}]
     norm('s:abc', aliases).should == [
       {nest_op: ':',
        nest_type: :colon,
        type: :nest,
        value: [{type: :str, value: 's'}, {type: :str, value: /abc/i}]}]
     norm('n:4', aliases).should == [
       {nest_op: ':',
        nest_type: :colon,
        type: :nest,
        value: [{type: :str, value: 'n'}, {type: :number, value: '4'}]}]
     norm('n:abc', aliases).should ==  [
       {nest_op: ':',
        nest_type: :colon,
        type: :nest,
        value: [{type: :str, value: 'n'}, {type: :str, value: 'abc'}]}]
  end

  it 'should cast dates' do
    aliases = { t: Time }

    def x(query, op, time)
      time = Chronic.parse(time) if time.is_a?(String)
      aliases = { t: Time }
      res = norm(query, aliases).first
      res[:nest_op].should == op
      res[:value][1][:value].should == time
    end

    x('t<1901', '<', Chronic.parse('1901-01-01 00:00:00'))
    x('t>1902', '>', Chronic.parse('1902-12-31 23:59:59'))
    x('t>=1903', '>=', Chronic.parse('1903-01-01 00:00:00'))
    x('t<=1903', '<=', Chronic.parse('1903-12-31 23:59:59'))
    x('t<1901-1-2', '<', Chronic.parse('1901-01-02 00:00:00'))
    x('t<9', '<', Time.new('0009-01-01 00:00:00'))
    x('t<hello', '<', nil)
    x('t:hello', ':', nil)

    norm('', aliases).should == []
    norm('t:1900', aliases).should == [
      {nest_op: ':',
       nest_type: :colon,
       type: :nest,
       value: [{type: :str, value: 't'},
               {type: Time, value: [Chronic.parse('1900-01-01 00:00:00'),
                                    Chronic.parse('1901-01-01 00:00:00')]}]}]
    norm('-t:1900', aliases).should == [
      {nest_op: '-',
       nest_type: :minus,
       type: :nest,
       value:
        [{nest_op: ':',
          nest_type: :colon,
          type: :nest,
          value:
           [{type: :str, value: 't'},
            {type: Time,
             value:
              [Chronic.parse('1900-01-01 00:00:00'),
               Chronic.parse('1901-01-01 00:00:00')]}]}]}]
    norm('-t<1901', aliases).should == [
      {nest_op: '-',
       nest_type: :minus,
       type: :nest,
       value:
        [{nest_op: '<',
          nest_type: :compare,
          type: :nest,
          value:
           [{type: :str, value: 't'},
            {type: Time, value: Chronic.parse('1901-01-01 00:00:00')}]}]}]
  end

end
