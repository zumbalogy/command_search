load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Parser do

  def parse(x)
    tokens = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(tokens)
  end

  it 'should not parse simple strings more than the lexer' do
    lexed = CommandSearch::Lexer.lex('foo 1 2 a b "1 ()"').select { |x| x[:type] != :space }
    lexed.should == parse('foo 1 2 a b "1 ()"')
    parse('red "blue green"').should == CommandSearch::Parser.parse!(parse('red "blue green"'))
    parse('foo').should == [{ type: :str, value: 'foo' }]
    parse('f1oo').should == [{ type: :str, value: 'f1oo' }]
    parse('a b 3 c').should == [
      { type: :str, value: 'a' },
      { type: :str, value: 'b' },
      { type: :number, value: '3' },
      { type: :str, value: 'c' }
    ]
  end

  it 'should handle parens' do
    parse('(a)').should == [{ type: :str, value: 'a' }]
    parse('(foo 1 2)').should == [
      {
        type: :and,
        value: [
          { type: :str, value: 'foo' },
          { type: :number, value: '1' },
          { type: :number, value: '2' }
        ]
      }
    ]
    parse('a (red 1 x) b').should == [
      { type: :str, value: 'a' },
      {
        type: :and,
        value: [
          { type: :str, value: 'red' },
          { type: :number, value: '1' },
          { type: :str, value: 'x' }
        ]
      },
      { type: :str, value: 'b' }
    ]
    parse('a (x (foo bar) y) b').should == [
      { type: :str, value: 'a' },
      {
        type: :and,
        value: [
          { type: :str, value: 'x' },
          {
            type: :and,
            value: [
              { type: :str, value: 'foo' },
              { type: :str, value: 'bar' }
            ]
          },
          { type: :str, value: 'y' }
        ]
      },
      { type: :str, value: 'b' }
    ]
    parse('1 (2 (3 (4 (5))) 6) 7').should == [
      { type: :number, value: '1' },
      {
        type: :and,
        value: [
          { type: :number, value: '2' },
          {
            type: :and,
            value: [
              { type: :number, value: '3' },
              {
                type: :and,
                value: [
                  { type: :number, value: '4' },
                  { type: :number, value: '5' }
                ]
              }
            ]
          },
          { type: :number, value: '6' }
        ]
      },
      { type: :number, value: '7' }
    ]
  end

  it 'should handle unbalanced parens' do
    parse('(').should == []
    parse('((').should == []
    parse(')(').should == []
    parse(')))').should == []
    parse('(foo').should == [{ type: :str, value: 'foo' }]
    parse(')bar))) ))((foo((').should == parse('bar foo')
  end

  it 'should handle OR statements' do
    parse('a|b').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    parse('a|1 2|b').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :number, value: '1' }
        ]
      },
      {
        type: :or,
        value: [
          { type: :number, value: '2' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    parse('a|b|3').should == [{
      type: :or,
      value: [
        {
          type: :or,
          value: [
            { type: :str, value: 'a' },
            { type: :str, value: 'b' }
          ]
        },
        { type: :number, value: '3' }
      ]
    }]
    parse('1.2|(x|yy)').should == [
      {
        type: :or,
        value: [
          { type: :number, value: '1.2' },
          {
            type: :and,
            value: [
              {
                type: :or,
                value: [
                  { type: :str, value: 'x' },
                  { type: :str, value: 'yy' }
                ]
              }
            ]
          }
        ]
      }
    ]
    parse('(a|b c)|z').should == [
      {
        type: :or,
        value: [
          {
            type: :and,
            value: [
              {
                type: :or,
                value: [
                  { type: :str, value: 'a' },
                  { type: :str, value: 'b' }
                ]
              },
              { type: :str, value: 'c' }
            ]
          },
          { type: :str, value: 'z' }
        ]
      }
    ]
  end

  it 'should handle unbalanced ORs' do
    parse('|a').should == [{ type: :str, value: 'a' }]
    parse('a|').should == [{ type: :str, value: 'a' }]
    parse('-|').should == [
      {
        type: :not,
        value: []
      }
    ]
  end

  it 'should handle negating' do
    parse('ab-dc').should == [{ type: :str, value: 'ab-dc' }]
    parse('-12.023').should == [{ type: :number, value: '-12.023' }]
    parse('a -(c b)').should == [
      { type: :str, value: 'a' },
      {
        type: :not,
        value: [{
          type: :and,
          value: [
            { type: :str, value: 'c' },
            { type: :str, value: 'b' }
          ]
        }]
      }
    ]
    parse('- -1').should == [
      {
        type: :not,
        value: [{ type: :number, value: '-1' }]
      }
    ]
    parse('-a').should == [
      {
        type: :not,
        value: [{ type: :str, value: 'a' }]
      }
    ]
    parse('- -a').should == [
      {
        type: :not,
        value: [{
          type: :not,
          value: [{ type: :str, value: 'a' }]
        }]
      }
    ]
    parse('-foo bar').should == [
      {
        type: :not,
        value: [{ type: :str, value: 'foo' }]
      },
      { type: :str, value: 'bar' }
    ]
    parse('-(1 foo)').should == [
      {
        type: :not,
        value: [
          {
            type: :and,
            value: [
              { type: :number, value: '1' },
              { type: :str, value: 'foo' }
            ]
          }
        ]
      }
    ]
    parse('-(-1 2 -foo)').should == [
      {
        type: :not,
        value: [
          {
            type: :and,
            value: [
              { type: :number, value: '-1' },
              { type: :number, value: '2' },
              {
                type: :not,
                value: [{ type: :str, value: 'foo' }]
              }
            ]
          }
        ]
      }
    ]
  end

  it 'should handle commands' do
    parse('foo:bar').should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'foo' },
          { type: :str, value: 'bar' }
        ]
      }
    ]

    parse('foo:bar a:b c').should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'foo' },
          { type: :str, value: 'bar' }
        ]
      },
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      },
      { type: :str, value: 'c' }
    ]
    parse('-a:b -(c d:e)').should == [
      {
        type: :not,
        value: [
          {
            type: :colon,
            nest_op: ':',
            value: [
              { type: :str, value: 'a' },
              { type: :str, value: 'b' }
            ]
          }
        ]
      },
      {
        type: :not,
        value: [
          {
            type: :and,
            value: [
              { type: :str, value: 'c' },
              {
                type: :colon,
                nest_op: ':',
                value: [
                  { type: :str, value: 'd' },
                  { type: :str, value: 'e' }
                ]
              }
            ]
          }
        ]
      }
    ]
  end

  it 'should handle comparisons' do
    parse('red>5').should == [
      {
        type: :compare,
        nest_op: '>',
        value: [
          { type: :str, value: 'red' },
          { type: :number, value: '5' }
        ]
      }
    ]
    parse('foo<=-5').should == [
      {
        type: :compare,
        nest_op: '<=',
        value: [
          { type: :str, value: 'foo' },
          { type: :number, value: '-5' }
        ]
      }
    ]
    parse('a<b b>=-1').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      },
      {
        type: :compare,
        nest_op: '>=',
        value: [
          { type: :str, value: 'b' },
          { type: :number, value: '-1' }
        ]
      }
    ]
  end

  it 'should handle bad commands and compares' do
    parse('foo:').should == [{ type: :str, value: 'foo:' }]
    parse(':foo').should == [{ type: :str, value: ':foo' }]
    parse(':foo:').should == [{ type: :str, value: ':foo:' }]
    parse('<=foo:').should == [{ type: :str, value: '<=foo:' }]
    parse('<=foo>=').should == [{ type: :str, value: '<=foo>=' }]
    parse('<=foo=>=').should == [{ type: :str, value: '<=foo=>=' }]
    parse('foo:-bar').should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'foo' },
          { type: :str, value: '-bar' }
        ]
      }
    ]
    parse('foo:-(bar x)').should == parse('foo:- (bar x)')
    parse(':--34').should == parse(':- -34')
    parse('a<<<b').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'a<<' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    parse('a<-<b').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: '-' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: '-' },
          { type: :str, value: 'b' }
        ]
      }
    ]
  end

  it 'should handle chained comparisons' do
    parse('-5<x<-10').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :number, value: '-5' },
          { type: :str, value: 'x' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'x' },
          { type: :number, value: '-10' }
        ]
      }
    ]
    parse('0<red<5').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :number, value: '0' },
          { type: :str, value: 'red' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'red' },
          { type: :number, value: '5' }
        ]
      }
    ]
    parse('cyan<blue>=-1>-34').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'cyan' },
          { type: :str, value: 'blue' }
        ]
      },
      {
        type: :compare,
        nest_op: '>=',
        value: [
          { type: :str, value: 'blue' },
          { type: :number, value: '-1' }
        ]
      },
      {
        type: :compare,
        nest_op: '>',
        value: [
          { type: :number, value: '-1' },
          { type: :number, value: '-34' }
        ]
      }
    ]
  end

  it 'should handle chained commands and compares' do
    abc = [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'b' },
          { type: :str, value: 'c' }
        ]
      }
    ]
    parse('a:b<c').should == abc
    parse('(a:b<c)').should == [{ type: :and, value: abc }]
    parse('a<b<c:d<e').should == [
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'b' },
          { type: :str, value: 'c' }
        ]
      },
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'c' },
          { type: :str, value: 'd' }
        ]
      },
      {
        type: :compare,
        nest_op: '<',
        value: [
          { type: :str, value: 'd' },
          { type: :str, value: 'e' }
        ]
      }
    ]
  end

  it 'should handle command syntax mid-command' do
    parse('foo:-bar').should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :str, value: 'foo' },
          { type: :str, value: '-bar' }
        ]
      }
    ]
    parse('foo:(bar)').should == [
      { type: :str, value: 'foo:' },
      { type: :str, value: 'bar' }
    ]
  end

  it 'should handle text emojis' do
    # NOTE: For now, users will have to use quotes around their text emojis
    def testStr(input)
      parse(input)[0][:value].should == input.tr('"\'', '')
      parse(input.reverse)[0][:value].should == input.reverse.tr('"\'', '')
    end
    testStr('":)"')
    testStr('":("')
    testStr('":-("')
    testStr('":-)"')
    testStr('";-)"')
    testStr('";("')
    testStr("';)'")
    testStr("';('")
    parse('":)" smile').should == [
      { type: :quote, value: ':)' },
      { type: :str, value: 'smile' }
    ]
  end

  it 'should handle wacky combinations' do
    parse('').should == []
    parse('|').should == []
    parse('(-)').should == []
    parse('(|)').should == []
    parse(' ( ( ()) -(()  )) ').should == []
    parse(':').should == [{ type: :str, value: ':' }]
    parse('foo -').should == [{ type: :str, value: 'foo' }]
    parse('<|a').should == [
      {
        type: :or,
        value: [
          { type: :str, value: '<' },
          { type: :str, value: 'a' }
        ]
      }
    ]
    parse("'(':a)").should == [
      {
        type: :colon,
        nest_op: ':',
        value: [
          { type: :quote, value: '(' },
          { type: :str, value: 'a' }
        ]
      }
    ]
  end
end
