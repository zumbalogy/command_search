load(__dir__ + '/./spec_helper.rb')

describe Lexer do

  it 'should handle empty strings' do
    Lexer.lex('').should == []
    Lexer.lex(' ').should == []
    Lexer.lex("    \n ").should == []
  end

  it 'should be able to split basic parts on spaces' do
    Lexer.lex('foo').should == [{type: :str, value: "foo"}]
    Lexer.lex('f1oo').should == [{type: :str, value: "f1oo"}]
    Lexer.lex('ab_cd').should == [{type: :str, value: "ab_cd"}]
    Lexer.lex('ab?cd').should == [{type: :str, value: "ab?cd"}]
    Lexer.lex('Dr.Foo').should == [{type: :str, value: "Dr.Foo"}]
    Lexer.lex('Dr.-Foo').should == [{type: :str, value: "Dr.-Foo"}]
    Lexer.lex('Dr.=Foo').should == [{type: :str, value: "Dr.=Foo"}]
    Lexer.lex('Dr=.Foo').should == [{type: :str, value: "Dr=.Foo"}]
    Lexer.lex('Dr-.Foo').should == [{type: :str, value: "Dr-.Foo"}]
    Lexer.lex('F.O.O.').should == [{type: :str, value: "F.O.O."}]
    Lexer.lex('foo-bar-').should == [{type: :str, value: "foo-bar-"}]
    Lexer.lex('foo=bar=').should == [{type: :str, value: "foo=bar="}]
    Lexer.lex('a b c 1 foo').should == [
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :number, value: "1"},
      {type: :str, value: "foo"}
    ]
    Lexer.lex('1 1 1').should == [
      {type: :number, value: "1"},
      {type: :number, value: "1"},
      {type: :number, value: "1"}
    ]
  end

  it 'should handle quotes, removing surrounding quotes' do
    Lexer.lex('"foo"').should == [{type: :quoted_str, value: "foo"}]
    Lexer.lex("'bar'").should == [{type: :quoted_str, value: "bar"}]
    Lexer.lex("a 'b foo'").should == [
      {type: :str, value: "a"},
      {type: :quoted_str, value: "b foo"}
    ]
    Lexer.lex("foo 'a b' bar").should == [
      {type: :str, value: "foo"},
      {type: :quoted_str, value: "a b"},
      {type: :str, value: "bar"}
    ]
    Lexer.lex("-3 '-11 x'").should == [
      {type: :number, value: "-3"},
      {type: :quoted_str, value: "-11 x"}
    ]
    Lexer.lex('a b " c').should == [
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :quote, value: "\""},
      {type: :str, value: "c"}
    ]
    Lexer.lex("a 'b \" c'").should == [
      {type: :str, value: "a"},
      {type: :quoted_str, value: "b \" c"}
    ]
    Lexer.lex('"a\'b"').should == [{type: :quoted_str, value: "a\'b"}]
    Lexer.lex("'a\"b'").should == [{type: :quoted_str, value: "a\"b"}]
    Lexer.lex("'a\"\"b'").should == [{type: :quoted_str, value: "a\"\"b"}]
    Lexer.lex('"a\'\'b"').should == [{type: :quoted_str, value: "a\'\'b"}]
    Lexer.lex("'red \"blue' \" green").should == [
      {type: :quoted_str, value: "red \"blue"},
      {type: :quote, value: '"'},
      {type: :str, value: "green"}
    ]
    Lexer.lex('"red \'blue" \' green').should == [
      {type: :quoted_str, value: "red \'blue"},
      {type: :quote, value: "'"},
      {type: :str, value: "green"}
    ]
  end

  it 'should handle OR statements' do
    Lexer.lex('a|b').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"}
    ]
    Lexer.lex('a|b c|d').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :pipe, value: "|"},
      {type: :str, value: "d"}
    ]
    Lexer.lex('a|b|c').should == [
      {type: :str, value: "a"},
      {type: :pipe, value: "|"},
      {type: :str, value: "b"},
      {type: :pipe, value: "|"},
      {type: :str, value: "c"}
    ]
  end

  it 'should handle negating' do
    Lexer.lex('-5').should == [{type: :number, value: "-5"}]
    Lexer.lex('-0.23').should == [{type: :number, value: "-0.23"}]
    Lexer.lex('-a').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "a"}
    ]
    Lexer.lex('-"foo bar"').should == [
      {type: :minus, value: "-"},
      {type: :quoted_str, value: "foo bar"}
    ]
    Lexer.lex('-"foo -bar" -x').should == [
      {type: :minus, value: "-"},
      {type: :quoted_str, value: "foo -bar"},
      {type: :minus, value: "-"},
      {type: :str, value: "x"}
    ]
    Lexer.lex('ab-cd').should == [{type: :str, value: "ab-cd"}]
    Lexer.lex('-ab-cd').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "ab-cd"}
    ]
  end

  it 'should handle commands' do
    Lexer.lex('foo:bar').should == [
      {type: :str, value: "foo"},
      {type: :colon, value: ":"},
      {type: :str, value: "bar"}
    ]
    Lexer.lex('a:b c:d e').should == [
      {type: :str, value: "a"},
      {type: :colon, value: ":"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :colon, value: ":"},
      {type: :str, value: "d"},
      {type: :str, value: "e"}
    ]
    Lexer.lex('-a:b c:-d').should == [
      {type: :minus, value: "-"},
      {type: :str, value: "a"},
      {type: :colon, value: ":"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :colon, value: ":"},
      {type: :minus, value: "-"},
      {type: :str, value: "d"}
    ]
    Lexer.lex('1:"2"').should == [
      {type: :number, value: "1"},
      {type: :colon, value: ":"},
      {type: :quoted_str, value: '2'}
    ]
  end

  it 'should handle comparisons' do
    Lexer.lex('red>5').should == [
      {type: :str, value: "red"},
      {type: :compare, value: ">"},
      {type: :number, value: "5"}
    ]
    Lexer.lex('blue<=green').should == [
      {type: :str, value: "blue"},
      {type: :compare, value: "<="},
      {type: :str, value: "green"}
    ]
    Lexer.lex('a<b c>=-1').should == [
      {type: :str, value: "a"},
      {type: :compare, value: "<"},
      {type: :str, value: "b"},
      {type: :str, value: "c"},
      {type: :compare, value: ">="},
      {type: :number, value: "-1"}
    ]
    Lexer.lex('a<=b<13').should == [
      {type: :str, value: "a"},
      {type: :compare, value: "<="},
      {type: :str, value: "b"},
      {type: :compare, value: "<"},
      {type: :number, value: "13"}
    ]
  end

  it 'should handle parens' do
    Lexer.lex('(a)').should == [
      {type: :paren, value: "("},
      {type: :str, value: "a"},
      {type: :paren, value: ")"}
    ]
    Lexer.lex('(a foo)').should == [
      {type: :paren, value: "("},
      {type: :str, value: "a"},
      {type: :str, value: "foo"},
      {type: :paren, value: ")"}
    ]
    Lexer.lex('(a (foo bar) b) c').should == [
      {type: :paren, value: "("},
      {type: :str, value: "a"},
      {type: :paren, value: "("},
      {type: :str, value: "foo"},
      {type: :str, value: "bar"},
      {type: :paren, value: ")"},
      {type: :str, value: "b"},
      {type: :paren, value: ")"},
      {type: :str, value: "c"}
    ]
  end

  it 'should handle OR and NOT with parens' do
    Lexer.lex('(a -(foo bar))').should == [
      {type: :paren, value: "("},
      {type: :str, value: "a"},
      {type: :minus, value: "-"},
      {type: :paren, value: "("},
      {type: :str, value: "foo"},
      {type: :str, value: "bar"},
      {type: :paren, value: ")"},
      {type: :paren, value: ")"}
    ]
    Lexer.lex('(a b) | (foo bar)').should == [
      {type: :paren, value: "("},
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :paren, value: ")"},
      {type: :pipe, value: "|"},
      {type: :paren, value: "("},
      {type: :str, value: "foo"},
      {type: :str, value: "bar"},
      {type: :paren, value: ")"}
    ]
  end

  it 'should handle wacky combinations' do
    Lexer.lex('(-)').should == [
      {type: :paren, value: "("},
      {type: :minus, value: "-"},
      {type: :paren, value: ")"}]
    Lexer.lex('(|)').should == [
      {type: :paren, value: "("},
      {type: :pipe, value: "|"},
      {type: :paren, value: ")"}]
  end
end
