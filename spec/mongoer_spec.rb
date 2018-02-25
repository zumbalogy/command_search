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
    fields = ['f1']
    q('foo', fields).should == { "f1"=>/foo/mi }
    q('red "blue green"', fields).should == { '$and' => [{"f1"=>/red/mi},
                                                         {"f1"=>/"blue green"/mi}]}
    q('foo 1 2', fields).should == {"$and"=>[{"f1"=>/foo/mi},
                                             {"f1"=>/1/mi},
                                             {"f1"=>/2/mi}]}
    fields = ['f1', 'f2']
    q('foo "blue green"', fields).should == {
      "$and"=>[{"$or"=>[{"f1"=>/foo/mi},
                        {"f2"=>/foo/mi}]},
               {"$or"=>[{"f1"=>/"blue green"/mi},
                        {"f2"=>/"blue green"/mi}]}]}
    q('foo 1 2', fields).should == {
      "$and"=>[{"$or"=>[{"f1"=>/foo/mi},
                        {"f2"=>/foo/mi}]},
               {"$or"=>[{"f1"=>/1/mi},
                        {"f2"=>/1/mi}]},
               {"$or"=>[{"f1"=>/2/mi},
                        {"f2"=>/2/mi}]}]}
  end

  it 'should handle ORs' do
    fields = ['f1', 'f2']
    q('a|b|(c|d) foo|bar', fields).should == {
      "$and"=>[
        {"$or"=>[
           {"f1"=>/a/mi},
           {"f2"=>/a/mi},
           {"f1"=>/b/mi},
           {"f2"=>/b/mi},
           {"f1"=>/c/mi},
           {"f2"=>/c/mi},
           {"f1"=>/d/mi},
           {"f2"=>/d/mi}]},
        {"$or"=>[
           {"f1"=>/foo/mi},
           {"f2"=>/foo/mi},
           {"f1"=>/bar/mi},
           {"f2"=>/bar/mi}]}]}
  end

  it 'should denest parens' do
    fields = ['f1', 'f2']
    q('(a b) | (c d)', fields).should == {
      "$or"=>[
        {"$and"=>[
           {"$or"=>[{"f1"=>/a/mi}, {"f2"=>/a/mi}]},
           {"$or"=>[{"f1"=>/b/mi}, {"f2"=>/b/mi}]}]},
        {"$and"=>[
           {"$or"=>[{"f1"=>/c/mi}, {"f2"=>/c/mi}]},
           {"$or"=>[{"f1"=>/d/mi}, {"f2"=>/d/mi}]}]}]}

    # q('1 (2 (3 (4 4.5 (5))) 6) 7').should == [
    #   {:type=>:number, :value=>"1"},
    #   {:type=>:number, :value=>"2"},
    #   {:type=>:number, :value=>"3"},
    #   {:type=>:number, :value=>"4"},
    #   {:type=>:number, :value=>"4.5"},
    #   {:type=>:number, :value=>"5"},
    #   {:type=>:number, :value=>"6"},
    #   {:type=>:number, :value=>"7"}]
  end

  # it 'should handle commands' do
  # end

  # it 'should handle compares' do
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

  it 'should return [] for empty nonsense' do
    fields = ['hello']
    q('', fields).should == []
    q('   ', fields).should == []
    q("   \n ", fields).should == []
    q('()', fields).should == []
    q(' ( ( ()) -(()  )) ', fields).should == []
    q('(-)', fields).should == []
    q('(|)', fields).should == []
  end


  # it 'should wacky inputs' do
  # end

end
