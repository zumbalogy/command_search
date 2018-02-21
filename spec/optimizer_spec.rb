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

# 'a b a|b' => 'a b'
# '(a b c) | (a b)' => 'a b'

load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/../lib/parser.rb')
load(__dir__ + '/../lib/optimizer.rb')
require('rspec')

# break this into a spec helper maybe
RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

def parse(x)
  tokens = Lexer.lex(x)
  Parser.parse(tokens)
end

def opt(x)
  Optimizer.optimize(parse(x))
end

require 'clipboard'
def gen(x)
  out = "opt('#{x}').should == #{opt(x)}"
  Clipboard.copy(out)
  pp opt(x)
  out
end

describe Parser do

  it 'should work and be a no-op in some cases' do
    opt('foo 1 2 a b').should == Optimizer.optimize(opt('foo 1 2 a b'))
    opt('red "blue green"').should == parse('red "blue green"')
    opt('foo 1 2').should == [
      {:type=>:str, :value=>"foo"},
      {:type=>:number, :value=>"1"},
      {:type=>:number, :value=>"2"}]
    str_list = [
      'foo',
      '-foo',
      '-5.2',
      '- -12',
      'ab-dc',
      'a a|b',
      'red "blue green"',
      '1 2 2.34 3 -100 -4.30',
      '(a b) | (c d)'
    ]
    str_list.each do |str|
      opt(str).should == parse(str)
    end
  end

  it 'should denest parens' do
    opt('a').should == [{:type=>:str, :value=>"a"}]
    opt('(a)').should == [{:type=>:str, :value=>"a"}]
    opt('(1 foo 2)').should == [
      {:type=>:number, :value=>"1"},
      {:type=>:str, :value=>"foo"},
      {:type=>:number, :value=>"2"}]
    opt('a (x (foo bar) y) b').should == [
      {:type=>:str, :value=>"a"},
      {:type=>:str, :value=>"x"},
      {:type=>:str, :value=>"foo"},
      {:type=>:str, :value=>"bar"},
      {:type=>:str, :value=>"y"},
      {:type=>:str, :value=>"b"}]
    opt('1 (2 (3 (4 4.5 (5))) 6) 7').should == [
      {:type=>:number, :value=>"1"},
      {:type=>:number, :value=>"2"},
      {:type=>:number, :value=>"3"},
      {:type=>:number, :value=>"4"},
      {:type=>:number, :value=>"4.5"},
      {:type=>:number, :value=>"5"},
      {:type=>:number, :value=>"6"},
      {:type=>:number, :value=>"7"}]
  end

  it 'should handle OR statements' do
    opt('a|b').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [{type: :str, value: "a"},
               {type: :str, value: "b"}]}]
    opt('a|1 2|b').should == [
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
    opt('a|b|3').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [
         {type: :str, value: "a"},
         {type: :str, value: "b"},
         {type: :number, value: "3"}]}]
    opt('(a) | (a|b)').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[{:type=>:str, :value=>"a"},
                {:type=>:str, :value=>"b"}]}]
    opt('a|(b|3)').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [
         {type: :str, value: "a"},
         {type: :str, value: "b"},
         {type: :number, value: "3"}]}]
    opt('a|(b|(3|4))').should == [
      {type: :nest,
       nest_type: :pipe,
       nest_op: "|",
       value: [
         {type: :str, value: "a"},
         {type: :str, value: "b"},
         {type: :number, value: "3"},
         {type: :number, value: "4"}]}]
    opt('(a|b|((c|d)|(e|f)))').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[
         {:type=>:str, :value=>"a"},
         {:type=>:str, :value=>"b"},
         {:type=>:str, :value=>"c"},
         {:type=>:str, :value=>"d"},
         {:type=>:str, :value=>"e"},
         {:type=>:str, :value=>"f"}]}]
    opt('(a|b|((c|d)|(e|f|g)))').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[
         {:type=>:str, :value=>"a"},
         {:type=>:str, :value=>"b"},
         {:type=>:str, :value=>"c"},
         {:type=>:str, :value=>"d"},
         {:type=>:str, :value=>"e"},
         {:type=>:str, :value=>"f"},
         {:type=>:str, :value=>"g"}]}]
    opt('(a|b|((c|d)|(e|f|g)|h|i)|j)|k|l').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[
         {:type=>:str, :value=>"a"},
         {:type=>:str, :value=>"b"},
         {:type=>:str, :value=>"c"},
         {:type=>:str, :value=>"d"},
         {:type=>:str, :value=>"e"},
         {:type=>:str, :value=>"f"},
         {:type=>:str, :value=>"g"},
         {:type=>:str, :value=>"h"},
         {:type=>:str, :value=>"i"},
         {:type=>:str, :value=>"j"},
         {:type=>:str, :value=>"k"},
         {:type=>:str, :value=>"l"}]}]
    opt('(a b) | (c d)').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[
         {:type=>:nest,
          :nest_type=>:paren,
          :value=>[{:type=>:str, :value=>"a"},
                   {:type=>:str, :value=>"b"}]},
         {:type=>:nest,
          :nest_type=>:paren,
          :value=>[{:type=>:str, :value=>"c"},
                   {:type=>:str, :value=>"d"}]}]}]
    opt('(a b) | (c d) | (x y)').should == [
      {:type=>:nest,
       :nest_type=>:pipe,
       :nest_op=>"|",
       :value=>[
         {:type=>:nest,
          :nest_type=>:paren,
          :value=>[{:type=>:str, :value=>"a"},
                   {:type=>:str, :value=>"b"}]},
         {:type=>:nest,
          :nest_type=>:paren,
          :value=>[{:type=>:str, :value=>"c"},
                   {:type=>:str, :value=>"d"}]},
         {:type=>:nest,
          :nest_type=>:paren,
          :value=>[{:type=>:str, :value=>"x"},
                   {:type=>:str, :value=>"y"}]}]}]
  end

  it 'should return [] for empty nonsense' do
    opt('').should == []
    opt('   ').should == []
    opt("   \n ").should == []
    opt('()').should == []
    opt(' ( ( ()) -(()  )) ').should == []
    # opt('(-)').should == []
    # opt('(|)').should == []
  end

  it 'should handle negating' do
    opt('- -a').should == [{type: :str, :value=>"a"}]
    # opt('- -1').should == [{type: :str, :value=>"a"}]
    # parse('- -1')

    # parse('-a')

    # parse('-foo bar')

    # parse('-(1 foo)')

    # parse('-(-1 2 -foo)')

  end

  # it 'should handle commands' do
  #   parse('foo:bar')

  #   parse('foo:bar a:b c')

  #   parse('-a:b -(c d:e)')

  # end

  # it 'should handle comparisons' do
  #   parse('red>5')

  #   parse('foo<=-5')

  #   parse('a<b b>=-1')


  #   # parse('1<5<10')
  # end

  # # it 'should handle wacky combinations' do
  # # end

end
