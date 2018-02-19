load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/../lib/parser.rb')
require('rspec')

# break this into a spec helper maybe
RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

def parse(x)
  tokens= Lexer.lex(x)
  Parser.parse(tokens)
end

describe Parser do
  it 'should not parse simple strings more than the lexer' do
    Lexer.lex('foo 1 2 a b').should == parse('foo 1 2 a b')
    Lexer.lex('red "blue green"').should == parse('red "blue green"')
    parse('red "blue green"').should == Parser.parse(parse('red "blue green"'))
    parse('foo').should == [{type: :str, value: "foo"}]
    parse('f1oo').should == [{type: :str, value: "f1oo"}]
    parse('a b 3 c').should == [
      {type: :str, value: "a"},
      {type: :str, value: "b"},
      {type: :number, value: "3"},
      {type: :str, value: "c"}]
  end

  it 'should handle parens' do
    parse('(a)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [{type: :str, value: "a"}]}]
    parse('(foo 1 2)').should == [
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: "foo"},
         {type: :number, value: "1"},
         {type: :number, value: "2"}]}]
    parse('a (red 1 x) b').should == [
      {type: :str, value: "a"},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: "red"},
         {type: :number, value: "1"},
         {type: :str, value: "x"}]},
      {type: :str, value: "b"}]
    parse('a (x (foo bar) y) b').should == [
      {type: :str, value: "a"},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :str, value: "x"},
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :str, value: "foo"},
            {type: :str, value: "bar"}]},
         {type: :str, value: "y"}]},
      {type: :str, value: "b"}]
    parse('1 (2 (3 (4 (5))) 6) 7').should == [
      {type: :number, value: "1"},
      {type: :nest,
       nest_type: :paren,
       value: [
         {type: :number, value: "2"},
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :number, value: "3"},
            {type: :nest,
             nest_type: :paren,
             value: 
               [{type: :number, value: "4"},
                {type: :nest,
                 nest_type: :paren,
                 value: [{type: :number, value: "5"}]}]}]},
         {type: :number, value: "6"}]},
      {type: :number, value: "7"}]
  end

  it 'should handle OR statements' do
    parse('a|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [{type: :str, value: "a"},
               {type: :str, value: "b"}]}]
    parse('a|1 2|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [{type: :str, value: "a"},
               {type: :number, value: "1"}]},
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [{type: :number, value: "2"},
               {type: :str, value: "b"}]}]
    parse('a|b|3').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: 
         [{type: :nest,
           nest_type: :pipe,
           nest_op: "|",
           value: [{type: :str, value: "a"},
                   {type: :str, value: "b"}]},
          {type: :number, value: "3"}]}]
    parse('1.2|(x|yy)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [
         {type: :number, value: "1.2"},
         {type: :nest,
          nest_type: :paren,
          value: 
            [{type: :nest,
              nest_type: :pipe,
              nest_op: "|",
              value: [{type: :str, value: "x"},
                      {type: :str, value: "yy"}]}]}]}]
  end

  it 'should handle negating' do
    parse('ab-dc').should == [{type: :str, value: "ab-dc"}]
    parse('-12.023').should == [{type: :number, value: "-12.023"}]
    parse('- -1').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [{type: :number, value: "-1"}]}]
    parse('-a').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [{type: :str, value: "a"}]}]
    parse('-foo bar').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [{type: :str, value: "foo"}]},
      {type: :str, value: "bar"}]
    parse('-(1 foo)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [{type: :number, value: "1"},
                  {type: :str, value: "foo"}]}]}]
    parse('-(-1 2 -foo)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :number, value: "-1"},
            {type: :number, value: "2"},
            {type: :nest,
             nest_type: :minus,
             nest_op: "-",
             value: [{type: :str, value: "foo"}]}]}]}]
  end

  it 'should handle commands' do
    parse('foo:bar').should == [
      {type: :nest,
       nest_type: :colon,
       nest_op: ":",
       value: [{type: :str, value: "foo"},
               {type: :str, value: "bar"}]}]

    parse('foo:bar a:b c').should == [
      {type: :nest,
       nest_type: :colon,
       nest_op: ":",
       value: [{type: :str, value: "foo"},
               {type: :str, value: "bar"}]},
      {type: :nest,
       nest_type: :colon,
       nest_op: ":",
       value: [{type: :str, value: "a"},
               {type: :str, value: "b"}]},
      {type: :str, value: "c"}]

    parse('-a:b -(c d:e)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [
         {type: :nest,
          nest_type: :colon,
          nest_op: ":",
          value: [{type: :str, value: "a"},
                  {type: :str, value: "b"}]}]},
      {type: :nest,
       nest_type: :minus,
       nest_op: "-",
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [
            {type: :str, value: "c"},
            {type: :nest,
             nest_type: :colon,
             nest_op: ":",
             value: [{type: :str, value: "d"},
                     {type: :str, value: "e"}]}]}]}]
  end

  it 'should handle comparisons' do
    parse('red>5').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: ">",
       value: [{type: :str, value: "red"},
               {type: :number, value: "5"}]}]
    parse('foo<=-5').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: "<=",
       value: [{type: :str, value: "foo"},
               {type: :number, value: "-5"}]}]
    parse('a<b b>=-1').should == [
      {type: :nest,
       nest_type: :compare,
       nest_op: "<",
       value: [{type: :str, value: "a"},
               {type: :str, value: "b"}]},
      {type: :nest,
       nest_type: :compare,
       nest_op: ">=",
       value: [{type: :str, value: "b"},
               {type: :number, value: "-1"}]}]

    # parse('1<5<10').should == ["1<5<10"]
  end

  # it 'should handle wacky combinations' do
  # end

end
