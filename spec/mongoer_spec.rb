load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/../lib/parser.rb')
load(__dir__ + '/../lib/optimizer.rb')
load(__dir__ + '/../lib/mongoer.rb')
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

def q(x, fields, command_types = {})
  Mongoer.build_query(opt(x), fields, command_types)
end

require 'clipboard'
def gen(x, y)
  out = "q('#{x}', fields).should == #{q(x, y)}"
  Clipboard.copy(out)
  pp q(x, y)
  out
end

describe Mongoer do

  it 'should work for basic string searches' do
    fields = ["f1"]
    q('foo', fields).should == { "f1"=>/foo/mi }
    q('red "blue green"', fields).should == { '$and' => [{"f1"=>/red/mi}, {"f1"=>/"blue green"/mi}]}
    # q('foo',).should ==
    # q('red "blue green"').should ==
    # q('foo 1 2').should ==
  end

  # it 'should denest parens' do
  #   q('a').should == [{:type=>:str, :value=>"a"}]
  #   q('(a)').should == [{:type=>:str, :value=>"a"}]
  #   q('(1 foo 2)').should == [
  #     {:type=>:number, :value=>"1"},
  #     {:type=>:str, :value=>"foo"},
  #     {:type=>:number, :value=>"2"}]
  #   q('a (x (foo bar) y) b').should == [
  #     {:type=>:str, :value=>"a"},
  #     {:type=>:str, :value=>"x"},
  #     {:type=>:str, :value=>"foo"},
  #     {:type=>:str, :value=>"bar"},
  #     {:type=>:str, :value=>"y"},
  #     {:type=>:str, :value=>"b"}]
  #   q('1 (2 (3 (4 4.5 (5))) 6) 7').should == [
  #     {:type=>:number, :value=>"1"},
  #     {:type=>:number, :value=>"2"},
  #     {:type=>:number, :value=>"3"},
  #     {:type=>:number, :value=>"4"},
  #     {:type=>:number, :value=>"4.5"},
  #     {:type=>:number, :value=>"5"},
  #     {:type=>:number, :value=>"6"},
  #     {:type=>:number, :value=>"7"}]
  # end

  # it 'should handle commands' do
  # end

  # it 'should handle compares' do
  # end

  # it 'should handle OR statements' do
  #   q('a|b').should == [
  #     {type: :nest,
  #      nest_type: :pipe,
  #      nest_op: "|",
  #      value: [{type: :str, value: "a"},
  #              {type: :str, value: "b"}]}]
  #   q('a|1 2|b').should == [
  #     {type: :nest,
  #      nest_type: :pipe,
  #      nest_op: "|",
  #      value: [{type: :str, value: "a"},
  #              {type: :number, value: "1"}]},
  #     {type: :nest,
  #      nest_type: :pipe,
  #      nest_op: "|",
  #      value: [{type: :number, value: "2"},
  #              {type: :str, value: "b"}]}]
  #   q('a|b|3').should == [
  #     {type: :nest,
  #      nest_type: :pipe,
  #      nest_op: "|",
  #      value: [
  #        {type: :str, value: "a"},
  #        {type: :str, value: "b"},
  #        {type: :number, value: "3"}]}]
  #   q('(a) | (a|b)').should == [
  #     {:type=>:nest,
  #      :nest_type=>:pipe,
  #      :nest_op=>"|",
  #      :value=>[{:type=>:str, :value=>"a"},
  #               {:type=>:str, :value=>"b"}]}]
  #   q('a|(b|(3|4))').should == [
  #     {type: :nest,
  #      nest_type: :pipe,
  #      nest_op: "|",
  #      value: [
  #        {type: :str, value: "a"},
  #        {type: :str, value: "b"},
  #        {type: :number, value: "3"},
  #        {type: :number, value: "4"}]}]
  #   q('(a|b|((c|d)|(e|f|g)|h|i)|j)|k|l').should == [
  #     {:type=>:nest,
  #      :nest_type=>:pipe,
  #      :nest_op=>"|",
  #      :value=>[
  #        {:type=>:str, :value=>"a"},
  #        {:type=>:str, :value=>"b"},
  #        {:type=>:str, :value=>"c"},
  #        {:type=>:str, :value=>"d"},
  #        {:type=>:str, :value=>"e"},
  #        {:type=>:str, :value=>"f"},
  #        {:type=>:str, :value=>"g"},
  #        {:type=>:str, :value=>"h"},
  #        {:type=>:str, :value=>"i"},
  #        {:type=>:str, :value=>"j"},
  #        {:type=>:str, :value=>"k"},
  #        {:type=>:str, :value=>"l"}]}]
  #   q('(a b) | (c d) | (x y)').should == [
  #     {:type=>:nest,
  #      :nest_type=>:pipe,
  #      :nest_op=>"|",
  #      :value=>[
  #        {:type=>:nest,
  #         :nest_type=>:paren,
  #         :value=>[{:type=>:str, :value=>"a"},
  #                  {:type=>:str, :value=>"b"}]},
  #        {:type=>:nest,
  #         :nest_type=>:paren,
  #         :value=>[{:type=>:str, :value=>"c"},
  #                  {:type=>:str, :value=>"d"}]},
  #        {:type=>:nest,
  #         :nest_type=>:paren,
  #         :value=>[{:type=>:str, :value=>"x"},
  #                  {:type=>:str, :value=>"y"}]}]}]
  # end

  # it 'should return [] for empty nonsense' do
  #   q('').should == []
  #   q('   ').should == []
  #   q("   \n ").should == []
  #   q('()').should == []
  #   q(' ( ( ()) -(()  )) ').should == []
  #   q('(-)').should == []
  #   q('(|)').should == []
  # end

  # it 'should handle negating' do
  #   q('- -a').should == [{type: :str, :value=>"a"}]
  #   q('-a').should == [
  #     {:type=>:nest,
  #      :nest_type=>:minus,
  #      :nest_op=>"-",
  #      :value=>[{:type=>:str, :value=>"a"}]}]
  #   q('- -1').should == [
  #     {:type=>:nest,
  #      :nest_type=>:minus,
  #      :nest_op=>"-",
  #      :value=>[{:type=>:number, :value=>"-1"}]}]
  #   q('-(-1 2 -foo)').should == [
  #     {:type=>:nest,
  #      :nest_type=>:minus,
  #      :nest_op=>"-",
  #      :value=>[
  #        {:type=>:number, :value=>"-1"},
  #        {:type=>:number, :value=>"2"},
  #        {:type=>:nest,
  #         :nest_type=>:minus,
  #         :nest_op=>"-",
  #         :value=>[{:type=>:str, :value=>"foo"}]}]}]
  # end

  # it 'should wacky inputs' do
  # end

end
