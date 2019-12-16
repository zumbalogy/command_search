load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Normalizer do

  def parse(x)
    ast = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize!(ast)
    ast
  end

  def norm(x, fields)
    ast = parse(x)
    CommandSearch::Normalizer.normalize!(ast, fields)
    ast
  end

  it 'should handle aliased commands and compares' do
    fields = {
      foo: :bar,
      bar: :baz,
      baz: { type: Numeric }
    }
    norm('-foo:100', fields)[0][:value].should == norm('foo:100', fields)
    norm('foo:100', fields).should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'baz', field_type: Numeric },
          { type: :number, value: 100.0 }
        ]
      }
    ]
    norm('foo<100', fields).should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'baz', field_type: Numeric },
          { type: :number, value: 100.0 }
        ]
      }
    ]
  end

  it 'should set unaliased commands to normal searches' do
    fields = { nnn: { type: String, general_search: true } }
    norm('foo foo:bar', fields).should_not == parse('foo foo:bar')
    norm('a:b', fields).should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /a:b/i }
      ]
    }]
    norm('-foo:bar', fields)[0][:value].should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /foo:bar/i }
      ]
    }]
    norm('-foo:bar|baz', fields)[0][:value][0][:value].should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /foo:bar/i }
      ]
    }]
  end

  it 'should cast booleans' do
    def c(x)
      fields = {
        a: :foo,
        foo: { type: Boolean },
        b: { type: Numeric, allow_existence_boolean: true },
        nnn: { type: String, general_search: true }
      }
      norm(x, fields)
    end
    c('a:true').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: true }
      ]
    }]
    c('a:false').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: false }
      ]
    }]
    c('a:foo').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: false }
      ]
    }]
    c('-a:true')[0][:value].should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: true }
      ]
    }]
    c('a:-true').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: false }
      ]
    }]
    c('a:-false').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo', field_type: Boolean },
        { type: Boolean, value: false }
      ]
    }]
    c('b:true').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :existence, value: true }
      ]
    }]
    c('b:false').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :existence, value: false }
      ]
    }]
    c('-b:true')[0][:value].should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :existence, value: true }
      ]
    }]
    c('-b:false')[0][:value].should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :existence, value: false }
      ]
    }]
    c('b:-true').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :str, value: '-true' }
      ]
    }]
    c('b:-false').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :str, value: '-false' }
      ]
    }]
    c('b:"false"').should == c("b:'false'")
    c('b:"true"').should == c("b:'true'")
    c('b:"false"').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :quote, value: 'false' }
      ]
    }]
    c('b:"true"').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :quote, value: 'true' }
      ]
    }]
    c('b:foo').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'b', field_type: Numeric },
        { type: :str, value: 'foo' }
      ]
    }]
    c('c:true').should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:true/i }
      ]
    }]
    c('c:false').should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:false/i }
      ]
    }]
    c('-c:true')[0][:value].should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:true/i }
      ]
    }]
    c('-c:false')[0][:value].should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:false/i }
      ]
    }]
    c('c:-true').should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:\-true/i }
      ]
    }]
    c('c:-false').should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /c:\-false/i }
      ]
    }]
  end

  it 'should cast regular expressions' do
    fields = {
      s: { type: String },
      n: { type: Integer },
      nnn: { type: String, general_search: true }
    }
    norm('', fields).should == []
    norm('foo', fields).should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :str, value: /foo/i }
      ]
    }]
    norm('"+foo"', fields).should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :quote, value: /(^|[^:+\w])\+foo($|[^:+\w])/ }
      ]
    }]
    norm('"foo?"', fields).should == [{
      type: :colon,
      value: [
        { value: 'nnn', field_type: String },
        { type: :quote, value: /(^|[^:+\w])foo\?($|[^:+\w])/ }
      ]
    }]
    norm('foo 5', fields).should == [
      {
        type: :colon,
        value: [
          { value: 'nnn', field_type: String },
          { type: :str, value: /foo/i }
        ]
      },
      {
        type: :colon,
        value: [
          { value: 'nnn', field_type: String },
          { type: :number, value: /5/i }
        ]
      }
    ]
    norm('-(foo|-bar)|3', fields).should == [{
      type: :or,
      value: [
        {
          type: :not,
          value: [{
            type: :or,
            value: [
              {
                type: :colon,
                value: [
                  { value: 'nnn', field_type: String },
                  { type: :str, value: /foo/i }
                ]
              },
              {
                type: :not,
                value: [{
                  type: :colon,
                  value: [
                    { value: 'nnn', field_type: String },
                    { type: :str, value: /bar/i }
                  ]
                }]
              }
            ]
          }]
        },
        {
          type: :colon,
          value: [
            { value: 'nnn', field_type: String },
            { type: :number, value: /3/i }
          ]
        }
      ]
    }]
    norm('s:-2', fields).should == [{
      nest_op: ':',
      type: :colon,
      value: [
        { type: :str, value: 's', field_type: String },
        { type: :number, value: /\-2/i }
      ]
    }]
    norm('s:abc', fields).should == [{
      nest_op: ':',
      type: :colon,
      value: [
        { type: :str, value: 's', field_type: String },
        { type: :str, value: /abc/i }
      ]
    }]
    norm('n:4', fields).should == [{
      nest_op: ':',
      type: :colon,
      value: [
        { type: :str, value: 'n', field_type: Numeric },
        { type: :number, value: 4.0 }
      ]
    }]
    norm('n:abc', fields).should == [{
      nest_op: ':',
      type: :colon,
      value: [
        { type: :str, value: 'n', field_type: Numeric },
        { type: :str, value: 'abc' }
      ]
    }]
  end

  it 'should cast dates' do
    fields = { t: { type: Time } }

    def x(query, op, time)
      time = Chronic.parse(time) if time.is_a?(String)
      fields = { t: { type: Time } }
      res = norm(query, fields).first
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

    norm('', fields).should == []
    norm('t:1900', fields).should == [
      {
        nest_op: ':',
        type: :colon,
        value: [
          { type: :str, value: 't', field_type: Time },
          {
            type: Time,
            value: [
              Chronic.parse('1900-01-01 00:00:00'),
              Chronic.parse('1901-01-01 00:00:00')
            ]
          }
        ]
      }
    ]
    norm('-t:1900', fields).should == [
      {
        type: :not,
        value: [{
          nest_op: ':',
          type: :colon,
          value: [
            { type: :str, value: 't', field_type: Time },
            {
              type: Time,
              value: [
                Chronic.parse('1900-01-01 00:00:00'),
                Chronic.parse('1901-01-01 00:00:00')
              ]
            }
          ]
        }]
      }
    ]
    norm('-t<1901', fields).should == [
      {
        type: :not,
        value: [{
          nest_op: '<',
          type: :compare,
          value: [
            { type: :str, value: 't', field_type: Time },
            { type: Time, value: Chronic.parse('1901-01-01 00:00:00') }
          ]
        }]
      }
    ]
  end

  it 'should flip operators in flipped comparisons' do
    def x(query, op, val1, val2)
      fields = {
        a: { type: Numeric },
        b: { type: Numeric }
      }
      res = norm(query, fields).first
      res[:nest_op].should == op
      res[:value][0][:value].should == val1
      res[:value][1][:value].should == val2
    end
    aliases = { a: Numeric, b: Numeric }
    x('a<b',  '<',  'a', 'b')
    x('a>=b', '>=', 'a', 'b')
    x('c>a',  '<',  'a', 'c')
    x('c<=a', '>=', 'a', 'c')
    x('a>=c', '>=', 'a', 'c')
    x('a<c',  '<',  'a', 'c')
    x('b<a',  '<',  'b', 'a')
    x('b>=a', '>=', 'b', 'a')
  end

end
