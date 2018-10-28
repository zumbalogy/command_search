# '()' => ''
# '-()' => ''
# '(a)' => a
# 'a (b c)' => 'a b c'
# '-(a)' => '-a'
# '-(-a)' => 'a'
# 'a a' => 'a'
# 'a|a' => 'a'
# 'a|a|b' => 'a|b'

# '-(a a)' => '-a'

# 'a (a (a (a (a))))' => 'a'

# 'a b (a b (a b))' => 'a b'
# 'a|b a|b' => 'a|b'

# TODO:

# 'a|-a' => ''
# 'a b a|b' => 'a b'
# '(a b c) | (a b)' => 'a b'

load(__dir__ + '/./spec_helper.rb')

def parse(x)
  tokens = CommandSearch::Lexer.lex(x)
  CommandSearch::Parser.parse(tokens)
end

def opt(x)
  CommandSearch::Optimizer.optimize(parse(x))
end

describe CommandSearch::Parser do

  it 'should work and be a no-op in some cases' do
    opt('foo 1 2 a b').should == CommandSearch::Optimizer.optimize(opt('foo 1 2 a b'))
    opt('red "blue green"').should == parse('red "blue green"')
    opt('foo 1 2').should == [
      {type: :str, value: "foo"},
      {type: :number, value: "1"},
      {type: :number, value: "2"}]
    str_list = [
      'foo',
      '-foo',
      '-foo:bar',
      'hello<=44.2',
      '-5.2',
      '- -12',
      'ab-dc',
      'a a|b',
      'a<=a',
      'red>red',
      'red>=blue',
      'red "blue green"',
      '1 2 2.34 3 -100 -4.30',
      '(a b) | (c d)'
    ]
    str_list.each do |str|
      opt(str).should == parse(str)
    end
  end

  it 'should denest parens' do
    opt('a').should == [{type: :str, value: 'a'}]
    opt('(a)').should == [{type: :str, value: 'a'}]
    opt('(1 foo 2)').should == [
      {type: :number, value: '1'},
      {type: :str, value: 'foo'},
      {type: :number, value: '2'}]
    opt('a (x (foo bar) y) b').should == [
      {type: :str, value: 'a'},
      {type: :str, value: 'x'},
      {type: :str, value: 'foo'},
      {type: :str, value: 'bar'},
      {type: :str, value: 'y'},
      {type: :str, value: 'b'}]
    opt('1 (2 (3 (4 4.5 (5))) 6) 7').should == [
      {type: :number, value: '1'},
      {type: :number, value: '2'},
      {type: :number, value: '3'},
      {type: :number, value: '4'},
      {type: :number, value: '4.5'},
      {type: :number, value: '5'},
      {type: :number, value: '6'},
      {type: :number, value: '7'}]
  end

  it 'should handle OR statements' do
    opt('a|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [{type: :str, value: 'a'},
               {type: :str, value: 'b'}]}]
    opt('a|1 2|b').should == [
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
    opt('a|b|3').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :number, value: '3'}]}]
    opt('(a) | (a|b)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [{type: :str, value: 'a'},
               {type: :str, value: 'b'}]}]
    opt('a|(b|3)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :number, value: '3'}]}]
    opt('a|(b|(3|4))').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :number, value: '3'},
         {type: :number, value: '4'}]}]
    opt('(a|b|((c|d)|(e|f)))').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :str, value: 'c'},
         {type: :str, value: 'd'},
         {type: :str, value: 'e'},
         {type: :str, value: 'f'}]}]
    opt('(a|b|((c|d)|(e|f|g)))').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :str, value: 'c'},
         {type: :str, value: 'd'},
         {type: :str, value: 'e'},
         {type: :str, value: 'f'},
         {type: :str, value: 'g'}]}]
    opt('(a|b|((c|d)|(e|f|g)|h|i)|j)|k|l').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :str, value: 'a'},
         {type: :str, value: 'b'},
         {type: :str, value: 'c'},
         {type: :str, value: 'd'},
         {type: :str, value: 'e'},
         {type: :str, value: 'f'},
         {type: :str, value: 'g'},
         {type: :str, value: 'h'},
         {type: :str, value: 'i'},
         {type: :str, value: 'j'},
         {type: :str, value: 'k'},
         {type: :str, value: 'l'}]}]
    opt('(a b) | (c d)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [{type: :str, value: 'a'},
                  {type: :str, value: 'b'}]},
         {type: :nest,
          nest_type: :paren,
          value: [{type: :str, value: 'c'},
                  {type: :str, value: 'd'}]}]}]
    opt('(a b) | (c d) | (x y)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: '|',
       value: [
         {type: :nest,
          nest_type: :paren,
          value: [{type: :str, value: 'a'},
                  {type: :str, value: 'b'}]},
         {type: :nest,
          nest_type: :paren,
          value: [{type: :str, value: 'c'},
                  {type: :str, value: 'd'}]},
         {type: :nest,
          nest_type: :paren,
          value: [{type: :str, value: 'x'},
                  {type: :str, value: 'y'}]}]}]
  end

  it 'should handle for empty nonsense' do
    opt('').should == []
    opt('   ').should == []
    opt("   \n ").should == []
    opt('()').should == []
    opt(' ( ( ()) -(()  )) ').should == []
    opt(' ( ( ()) -((-(()||(()|()))|(()|())-((-())))  )) ').should == []
  end

  it 'should handle wacky nonsense' do
    opt('(-)').should == []
    opt('(|)').should == []
    opt('(:)').should == []
    opt('(()').should == []
    opt(')())').should == []
    opt('(())').should == []
    opt(':').should == []
    opt('-').should == []
    opt('|').should == []
    opt('>').should == []
    opt('>>').should == []
    opt('>=').should == []
    opt('>=>').should == []
    opt('<').should == []
    opt('<=').should == []
    opt('-<').should == []
    opt('-<=').should == []
    opt('|:)').should == []
    opt('-<>=-()<>:|(>=-|:)').should == []
  end

  it 'should handle empty strings' do
    opt('""').should == []
    opt("''").should == []
    opt("'' foo").should == [{type: :str, value: 'foo'}]
  end

  it 'should handle single sides ORs' do
    opt('|a').should == [{type: :str, value: 'a'}]
    opt('a|').should == [{type: :str, value: 'a'}]
    opt('||||a').should == [{type: :str, value: 'a'}]
    opt('a||').should == [{type: :str, value: 'a'}]
    opt('|a|').should == [{type: :str, value: 'a'}]
    opt('||a|||').should == [{type: :str, value: 'a'}]
    opt('||a|()||').should == [{type: :str, value: 'a'}]
  end

  it 'should handle negating' do
    opt('- -a').should == [{type: :str, value: 'a'}]
    opt('-a').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :str, value: 'a'}]}]
    opt('- -1').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [{type: :number, value: '-1'}]}]
    opt('-(-1 2 -foo)').should == [
      {type: :nest,
       nest_type: :minus,
       nest_op: '-',
       value: [
         {type: :number, value: '-1'},
         {type: :number, value: '2'},
         {type: :nest,
          nest_type: :minus,
          nest_op: '-',
          value: [{type: :str, value: 'foo'}]}]}]
  end

  # it 'should handle fancier logic' do
  #   opt('a b a|b').should == [{type: :str, value: 'a'},
  #                             {type: :str, value: 'b'}]
  #   opt('(a b c) | (a b)').should == [{type: :str, value: 'a'},
  #                                     {type: :str, value: 'b'}]
  # end

end
