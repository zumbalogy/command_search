load(__dir__ + '/../lib/lexer.rb')
load(__dir__ + '/./spec_helper.rb')

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
  end

  it 'should handle basic commands' do
    def q2(s); q(s, ['f1'], { str1: String, num1: Numeric }); end
    q2('str1:red').should == {'str1'=>/red/mi}
    q2('str1:12.2').should == {'str1'=>/12.2/mi}
    q2('num1:-230').should == {'num1'=>-230}
    q2('num1:-0.930').should == {'num1'=>-0.930}
    q2('num1:4.0').should == {'num1'=>4.0}
    # TODO:
    #   q('num1:red').should == error
    #   consider the case of "num1:2 num1:3" and
    #   "str1:foo str1:bar". latter is valid, as
    #   regex match against substrings, but num1 one
    #   is strange.
  end

  # it 'should handle aliased commands' do
  # end

  # it 'should handle boolean commands' do
  # end

  # it 'should handle time commands' do
  #   fields = ['f1']
  #   commands = { str1: String, int1: Integer }
  # end

  it 'should handle compares' do
    def q2(s); q(s, ['f1'], { num1: Numeric }); end
    q2('num1<-230').should == {'num1'=>{'$lt'=>-230}}
    q2('num1<=5.20').should == {'num1'=>{'$lte'=>5.20}}
    q2('num1>0').should == {'num1'=>{'$gt'=>0}}
    q2('num1>=1000').should == {'num1'=>{'$gte'=>1000}}
  end

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
