load(__dir__ + '/./spec_helper.rb')

def parse(x)
  tokens = CommandSearch::Lexer.lex(x)
  CommandSearch::Parser.parse(tokens)
end

describe CommandSearch::Parser do
  it 'should not parse simple strings more than the lexer' do
    CommandSearch::Lexer.lex('foo 1 2 a b').should == parse('foo 1 2 a b')
    CommandSearch::Lexer.lex('red "blue green"').should == parse('red "blue green"')
    parse('red "blue green"').should == CommandSearch::Parser.parse(parse('red "blue green"'))
    parse('foo').should == [{type: :str, value: 'foo'}]
    parse('f1oo').should == [{type: :str, value: 'f1oo'}]
    parse('a b 3 c').should == [
      {type: :str, value: 'a'},
      {type: :str, value: 'b'},
      {type: :number, value: '3'},
      {type: :str, value: 'c'}]
  end

  it 'should handle parens' do
    parse('(a)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [{type: :str, value: 'a'}]}]
    parse('(foo 1 2)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: 'foo'},
         {type: :number, value: '1'},
         {type: :number, value: '2'}]}]
    parse('a (red 1 x) b').should == [
      {type: :str, value: 'a'},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: 'red'},
         {type: :number, value: '1'},
         {type: :str, value: 'x'}]},
      {type: :str, value: 'b'}]
    parse('a (x (foo bar) y) b').should == [
      {type: :str, value: 'a'},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: 'x'},
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :str, value: 'foo'},
            {type: :str, value: 'bar'}]},
         {type: :str, value: 'y'}]},
      {type: :str, value: 'b'}]
    parse('1 (2 (3 (4 (5))) 6) 7').should == [
      {type: :number, value: '1'},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :number, value: '2'},
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :number, value: '3'},
            {type: :nest,
             nest_type: :paren,
             value: [
               {type: :number, value: '4'},
               {type: :nest,
                nest_type: :paren,
                value: [{type: :number, value: '5'}]}]}]},
         {type: :number, value: '6'}]},
      {type: :number, value: '7'}]
  end

  it 'should handle unbalanced parens' do
    parse('(').should == []
    parse('((').should == []
    parse(')(').should == []
    parse(')))').should == []
    parse('(foo').should == [{type: :str, value: 'foo'}]
    parse(')bar))) ))((foo((').should == parse('bar foo')
  end

  it 'should handle OR statements' do
    parse('a|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [{type: :str, value: 'a'},
               {type: :str, value: 'b'}]}]
    parse('a|1 2|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [{type: :str, value: 'a'},
               {type: :number, value: '1'}]},
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [{type: :number, value: '2'},
               {type: :str, value: 'b'}]}]
    parse('a|b|3').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :nest,
          nest_type: :pipe,
          nest_op: '|',
          value: [
            {type: :str, value: 'b'},
            {type: :number, value: '3'}]}]}]
    parse('1.2|(x|yy)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :number, value: '1.2'},
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :nest,
             nest_type: :pipe,
             nest_op: '|',
             value: [
               {type: :str, value: 'x'},
               {type: :str, value: 'yy'}]}]}]}]
  end

  it 'should handle unbalanced ORs' do
    parse('|a').should == [
      {
        type: :nest,
        nest_type: :pipe,
        nest_op: '|',
        value: [
          {type: :str, value: 'a'}
        ]
      }
    ]
    parse('a|').should == [
      {
        type: :nest,
        nest_type: :pipe,
        nest_op: '|',
        value: [
          {type: :str, value: 'a'}
        ]
      }
    ]
  end

it 'should handle negating' do
    parse('ab-dc').should == [{type: :str, value: 'ab-dc'}]
    parse('-12.023').should == [{type: :number, value: '-12.023'}]
    parse('a -(c b)').should == [
      {type: :str, value: 'a'},
      {type: :nest,
        nest_type: :minus,
        nest_op: '-',
        value:
        [{type: :nest,
          nest_type: :paren,
          value: [
            {type: :str, value: 'c'},
            {type: :str, value: 'b'}]}]}]
    parse('- -1').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :number, value: '-1'}]}]
    parse('-a').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :str, value: 'a'}]}]
    parse('- -a').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :nest,
               nest_type: :minus,
               nest_op: '-',
               value: [{type: :str, value: 'a'}]}]}]
    parse('-foo bar').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :str, value: 'foo'}]},
      {type: :str, value: 'bar'}]
    parse('-(1 foo)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [{type: :number, value: '1'},
                  {type: :str, value: 'foo'}]}]}]
    parse('-(-1 2 -foo)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :number, value: '-1'},
            {type: :number, value: '2'},
            {type: :nest,
             nest_type: :minus,
             nest_op: '-',
             value: [{type: :str, value: 'foo'}]}]}]}]
  end

  it 'should handle commands' do
    parse('foo:bar').should == [
      {type: :nest,
       nest_type: :colon,
       nest_op: ':',
       value: [{type: :str, value: 'foo'},
               {type: :str, value: 'bar'}]}]

    parse('foo:bar a:b c').should == [
      {type: :nest,
       nest_type: :colon,
       nest_op: ':',
       value: [{type: :str, value: 'foo'},
               {type: :str, value: 'bar'}]},
      {type: :nest,
       nest_type: :colon,
       nest_op: ':',
       value: [{type: :str, value: 'a'},
               {type: :str, value: 'b'}]},
      {type: :str, value: 'c'}]
    parse('-a:b -(c d:e)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [
         {type: :nest,
          nest_type: :colon,
          nest_op: ':',
          value: [{type: :str, value: 'a'},
                  {type: :str, value: 'b'}]}]},
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :str, value: 'c'},
            {type: :nest,
             nest_type: :colon,
             nest_op: ':',
             value: [{type: :str, value: 'd'},
                     {type: :str, value: 'e'}]}]}]}]
  end

  it 'should handle comparisons' do
    parse('red>5').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '>',
       value: [{type: :str, value: 'red'},
               {type: :number, value: '5'}]}]
    parse('foo<=-5').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<=',
       value: [{type: :str, value: 'foo'},
               {type: :number, value: '-5'}]}]
    parse('a<b b>=-1').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: 'a'},
               {type: :str, value: 'b'}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: '>=',
       value: [{type: :str, value: 'b'},
               {type: :number, value: '-1'}]}]
  end

  it 'should handle chained comparisons' do
    parse('-5<x<-10').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :number, value: '-5'},
               {type: :str, value: 'x'}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: 'x'},
               {type: :number, value: '-10'}]}]
    parse('0<red<5').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :number, value: '0'},
               {type: :str, value: 'red'}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: 'red'},
               {type: :number, value: '5'}]}]
    parse('cyan<blue>=-1>-34').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: '<',
       value: [{type: :str, value: 'cyan'},
               {type: :str, value: 'blue'}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: '>=',
       value: [{type: :str, value: 'blue'},
               {type: :number, value: '-1'}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: '>',
       value: [{type: :number, value: '-1'},
               {type: :number, value: '-34'}]}]
  end

  it 'should handle wacky combinations' do
    parse(':').should == [{type: :nest, nest_type: :colon, nest_op: ':', value: []}]
    parse('|').should == [{type: :nest, nest_type: :pipe, nest_op: '|', value: []}]
    parse('(-)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [{type: :nest, nest_type: :minus, nest_op: '-', value: []}]}]
    parse('(|)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [{type: :nest, nest_type: :pipe, nest_op: '|', value: []}]}]
  end
end
