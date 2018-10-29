load(__dir__ + '/./spec_helper.rb')

def lex(input)
  CommandSearch::Lexer.lex(input)
end

describe CommandSearch::Lexer do

  it 'should handle empty strings' do
    lex('').should == []
    lex(' ').should == []
    lex("    \n ").should == []
  end

  it 'should correctly categorize strings' do
    lex('foo').should == [{type: :str, value: "foo"}]
    lex('f1oo').should == [{type: :str, value: "f1oo"}]
    lex('ab_cd').should == [{type: :str, value: "ab_cd"}]
    lex('ab?cd').should == [{type: :str, value: "ab?cd"}]
    lex('F.O.O.').should == [{type: :str, value: "F.O.O."}]
    lex('Dr.Foo').should == [{type: :str, value: "Dr.Foo"}]
    lex('Dr.-Foo').should == [{type: :str, value: "Dr.-Foo"}]
    lex('Dr.=Foo').should == [{type: :str, value: "Dr.=Foo"}]
    lex('Dr=.Foo').should == [{type: :str, value: "Dr=.Foo"}]
    lex('Dr-.Foo').should == [{type: :str, value: "Dr-.Foo"}]
    lex('foo-bar-').should == [{type: :str, value: "foo-bar-"}]
    lex('foo=bar=').should == [{type: :str, value: "foo=bar="}]
    lex('a1-.2').should == [{type: :str, value: "a1-.2"}]
    lex('1-.2').should == [{type: :str, value: "1-.2"}]
    lex('1.-2').should == [{type: :str, value: "1.-2"}]
  end

  it 'should be able to split basic parts on spaces' do
    lex('a b c 1 foo').should == [
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :number, value: "1"},
      {type: :str, value: "foo"}
    ]
    lex('1 1 1').should == [
      {type: :number, value: "1"},
      {type: :number, value: "1"},
      {type: :number, value: "1"}
    ]
  end

  it 'should handle quotes, removing surrounding quotes' do
    lex('"foo"').should == [{type: :quoted_str, value: "foo"}]
    lex("'bar'").should == [{type: :quoted_str, value: "bar"}]
    lex("a 'b foo'").should == [
      {type: :str, value: "a"},
      {type: :quoted_str, value: "b foo"}
    ]
    lex("foo 'a b' bar").should == [
      {type: :str, value: "foo"},
      {type: :quoted_str, value: "a b"},
      {type: :str, value: "bar"}
    ]
    lex("-3 '-11 x'").should == [
      {type: :number, value: "-3"},
      {type: :quoted_str, value: "-11 x"}
    ]
    lex('a b " c').should == [
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :str, value: "\""},
      {type: :str, value: "c"}
    ]
    lex("a 'b \" c'").should == [
      {type: :str, value: "a"},
      {type: :quoted_str, value: "b \" c"}
    ]
    lex('"a\'b"').should == [{type: :quoted_str, value: "a\'b"}]
    lex("'a\"b'").should == [{type: :quoted_str, value: "a\"b"}]
    lex("'a\"\"b'").should == [{type: :quoted_str, value: "a\"\"b"}]
    lex('"a\'\'b"').should == [{type: :quoted_str, value: "a\'\'b"}]
    lex("'red \"blue' \" green").should == [
      {type: :quoted_str, value: "red \"blue"},
      {type: :str, value: '"'},
      {type: :str, value: "green"}
    ]
    lex('"red \'blue" \' green').should == [
      {type: :quoted_str, value: "red \'blue"},
      {type: :str, value: "'"},
      {type: :str, value: "green"}
    ]
  end

  it 'should handle OR statements' do
    lex('a|b').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"}
    ]
    lex('a|b c|d').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :pipe, value: "|"},
      {type: :str, value: "d"}
    ]
    lex('a|b|c').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"},
      {type: :pipe, value: "|"},
      {type: :str, value: "c"}
    ]
    lex("'desk1'|'desk2'").should == [
      {type: :quoted_str, value: "desk1"},
      {type: :pipe, value: "|"},
      {type: :quoted_str, value: "desk2"}
    ]
    lex('"desk1"|"desk2"').should == [
      {type: :quoted_str, value: "desk1"},
      {type: :pipe, value: "|"},
      {type: :quoted_str, value: "desk2"}
    ]
    lex("\"desk1\"|'desk2'").should == [
      {type: :quoted_str, value: "desk1"},
      {type: :pipe, value: "|"},
      {type: :quoted_str, value: "desk2"}
    ]
  end

  it 'should handle duplicate pipe operators' do
    lex('a||b|c').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "||"},
      {type: :str, value: "b"},
      {type: :pipe, value: "|"},
      {type: :str, value: "c"}
    ]
    lex('a||b||||c').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "||"},
      {type: :str, value: "b"},
      {type: :pipe, value: "||||"},
      {type: :str, value: "c"}
    ]
  end

  it 'should handle negating' do
    lex('-5').should == [{type: :number, value: "-5"}]
    lex('-0.23').should == [{type: :number, value: "-0.23"}]
    lex('-a').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "a"}
    ]
    lex('-"foo bar"').should == [
      {type: :minus, value: "-"},
      {type: :quoted_str, value: "foo bar"}
    ]
    lex('-"foo -bar" -x').should == [
      {type: :minus, value: "-"},
      {type: :quoted_str, value: "foo -bar"},
      {type: :minus, value: "-"},
      {type: :str, value: "x"}
    ]
    lex('ab-cd').should == [{type: :str, value: "ab-cd"}]
    lex('-ab-cd').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "ab-cd"}
    ]
  end

  it 'should handle commands' do
    lex('foo:bar').should == [
      {type: :str, value: "foo"},
      {type: :colon, value: ":"},
      {type: :str, value: "bar"}
    ]
    lex('a:b c:d e').should == [
      {type: :str, value: "a"},
      {type: :colon, value: ":"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :colon, value: ":"},
      {type: :str, value: "d"},
      {type: :str, value: "e"}
    ]
    lex('-a:b c:-d').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "a"},
      {type: :colon, value: ":"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :colon, value: ":"},
      {type: :minus, value: "-"},
      {type: :str, value: "d"}
    ]
    lex('1:"2"').should == [
      {type: :number, value: "1"},
      {type: :colon, value: ":"},
      {type: :quoted_str, value: '2'}
    ]
  end

  it 'should handle comparisons' do
    lex('red>5').should == [
      {type: :str, value: "red"},
      {type: :compare, value: ">"},
      {type: :number, value: "5"}
    ]
    lex('blue<=green').should == [
      {type: :str, value: "blue"},
      {type: :compare, value: "<="},
      {type: :str, value: "green"}
    ]
    lex('a<b c>=-1').should == [
      {type: :str, value: "a"},
      {type: :compare, value: "<"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :compare, value: ">="},
      {type: :number, value: "-1"}
    ]
    lex('a<=b<13').should == [
      {type: :str, value: "a"},
      {type: :compare, value: "<="},
      {type: :str, value: "b"},
      {type: :compare, value: "<"},
      {type: :number, value: "13"}
    ]
    lex('-5<x<-10').should == [
      {type: :number, value: '-5'},
      {type: :compare, value: '<'},
      {type: :str, value: 'x'},
      {type: :compare, value: '<'},
      {type: :number, value: '-10'}
    ]
  end

  it 'should handle spaces in comparisons' do
    lex('red>5').should == lex('red > 5')
    lex('foo<=Monday').should == lex('foo <= Monday')
    lex('foo<=Monday').should_not == lex('foo < = Monday')
  end

  it 'should handle parens' do
    lex('(a)').should == [
      {type: :paren, value: '('},
      {type: :str, value: 'a'},
      {type: :paren, value: ')'}
    ]
    lex('(a foo)').should == [
      {type: :paren, value: '('},
      {type: :str, value: 'a'},
      {type: :str, value: 'foo'},
      {type: :paren, value: ')'}
    ]
    lex('(a (foo bar) b) c').should == [
      {type: :paren, value: '('},
      {type: :str, value: 'a'},
      {type: :paren, value: '('},
      {type: :str, value: 'foo'},
      {type: :str, value: 'bar'},
      {type: :paren, value: ')'},
      {type: :str, value: 'b'},
      {type: :paren, value: ')'},
      {type: :str, value: 'c'}
    ]
    lex('(2)').should == [
      {type: :paren, value: '('},
      {type: :number, value: '2'},
      {type: :paren, value: ')'}
    ]
  end

  it 'should handle OR and NOT with parens' do
    lex('(a -(foo bar))').should == [
      {type: :paren, value: '('},
      {type: :str, value: 'a'},
      {type: :minus, value: '-'},
      {type: :paren, value: '('},
      {type: :str, value: 'foo'},
      {type: :str, value: 'bar'},
      {type: :paren, value: ')'},
      {type: :paren, value: ')'}
    ]
    lex('(a b) | (foo bar)').should == [
      {type: :paren, value: '('},
      {type: :str, value: 'a'},
      {type: :str, value: 'b'},
      {type: :paren, value: ')'},
      {type: :pipe, value: '|'},
      {type: :paren, value: '('},
      {type: :str, value: 'foo'},
      {type: :str, value: 'bar'},
      {type: :paren, value: ')'}
    ]
  end

  it 'should handle wacky combinations' do
    lex('(-)').should == [
      {type: :paren, value: '('},
      {type: :minus, value: '-'},
      {type: :paren, value: ')'}]
    lex('(|)').should == [
      {type: :paren, value: '('},
      {type: :pipe, value: '|'},
      {type: :paren, value: ')'}]
  end
end
