load(__dir__ + '/./spec_helper.rb')

def parse(x)
  tokens = CommandSearch::Lexer.lex(x)
  CommandSearch::Parser.parse(tokens)
end

def opt(x)
  CommandSearch::Optimizer.optimize(parse(x))
end

def q(x, fields, command_types = {})
  parsed = opt(x)
  dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_types)
  CommandSearch::Mongoer.build_query(dealiased, fields, command_types)
end

describe CommandSearch::Mongoer do

  it 'should work for basic string searches' do
    fields = ['f1']
    q('foo', fields).should == { "f1"=>/foo/mi }
    q('red "blue green"', fields).should == { '$and' => [{'f1'=>/red/mi},
                                                         {'f1'=>/\bblue\ green\b/}]}
    q('foo 1 2', fields).should == {'$and'=>[{'f1'=>/foo/mi},
                                             {'f1'=>/1/mi},
                                             {'f1'=>/2/mi}]}
    fields = ['f1', 'f2']
    q('red', fields).should == {'$or'=>[{'f1'=>/red/mi},
                                        {'f2'=>/red/mi}]}
    q('"red"', fields).should == {'$or'=>[{'f1'=>/\bred\b/},
                                          {'f2'=>/\bred\b/}]}
    q('foo "blue green"', fields).should == {
      '$and'=>[{'$or'=>[{'f1'=>/foo/mi},
                        {'f2'=>/foo/mi}]},
               {'$or'=>[{'f1'=>/\bblue\ green\b/},
                        {'f2'=>/\bblue\ green\b/}]}]}
    q('foo 1 2', fields).should == {
      '$and'=>[{'$or'=>[{'f1'=>/foo/mi},
                        {'f2'=>/foo/mi}]},
               {'$or'=>[{'f1'=>/1/mi},
                        {'f2'=>/1/mi}]},
               {'$or'=>[{'f1'=>/2/mi},
                        {'f2'=>/2/mi}]}]}
  end

  it 'should sanitize inputs' do
    def q2(s); q(s, ['f1'], { str1: String }); end
    q2('"a b"').should == {"f1"=>/\ba\ b\b/}
    q2("str1:'a-b'").should == {"str1"=>/\ba\-b\b/}
  end

  it 'should handle ORs' do
    fields = ['f1', 'f2']
    q('a|b|(c|d) foo|bar', fields).should == {
      '$and'=>[
        {'$or'=>[
           {'f1'=>/a/mi},
           {'f2'=>/a/mi},
           {'f1'=>/b/mi},
           {'f2'=>/b/mi},
           {'f1'=>/c/mi},
           {'f2'=>/c/mi},
           {'f1'=>/d/mi},
           {'f2'=>/d/mi}]},
        {'$or'=>[
           {'f1'=>/foo/mi},
           {'f2'=>/foo/mi},
           {'f1'=>/bar/mi},
           {'f2'=>/bar/mi}]}]}
  end

  it 'should denest parens' do
    fields = ['f1', 'f2']
    q('(a b) | (c d)', fields).should == {
      '$or'=>[
        {'$and'=>[
           {'$or'=>[{'f1'=>/a/mi}, {'f2'=>/a/mi}]},
           {'$or'=>[{'f1'=>/b/mi}, {'f2'=>/b/mi}]}]},
        {'$and'=>[
           {'$or'=>[{'f1'=>/c/mi}, {'f2'=>/c/mi}]},
           {'$or'=>[{'f1'=>/d/mi}, {'f2'=>/d/mi}]}]}]}
  end

  it 'should handle basic commands' do
    def q2(s); q(s, ['f1'], { str1: String, num1: Numeric }); end
    q2('str1:red').should == {'str1'=>/red/mi}
    q2('str1:12.2').should == {'str1'=>/12\.2/mi}
    q2('num1:-230').should == {'num1'=>-230}
    q2('num1:-0.930').should == {'num1'=>-0.930}
    q2('num1:4.0').should == {'num1'=>4.0}
    q2('num1:red').should == {'num1'=>'red'}
  end

  it 'should handle time commands' do
    def q2(s); q(s, [], { created: Time }); end
    res = q2('created:yesterday')
    start = res['$and'].first['created']['$gte']
    stop = res['$and'].last['created']['$lte']
    (stop - start).should == (60 * 60 * 24)
    q2('created:"april 10 2000"').should == {
      '$and'=>[
        {'created'=>{'$gte'=>Chronic.parse('2000-04-10 00:00:00')}},
        {'created'=>{'$lte'=>Chronic.parse('2000-04-11 00:00:00')}}]}
    q2('-created:"april-10.2000"').should == {
      '$or'=>[
        {'created'=>{'$gt'=>Chronic.parse('2000-04-11 00:00:00')}},
        {'created'=>{'$lt'=>Chronic.parse('2000-04-10 00:00:00')}}]}
  end

  it 'should handle boolean commands' do
    def q1(s); q(s, [], { b: Boolean }); end
    q1('b:true').should == {'$and'=>[{'b'=>{'$exists'=>true}}, {'b'=>{'$ne'=>false}}]}
    q1('b:false').should == {'$and'=>[{'b'=>{'$exists'=>true}}, {'b'=>{'$ne'=>true}}]}
    def q2(s); q(s, [], { paid: :paid_at, paid_at: [Date, :allow_existence_boolean] }); end
    # q2('paid:true').should == {'paid_at'=>{'$exists'=>true}}
    # q2('paid:false').should == {'paid_at'=>{'$exists'=>false}}
    def q3(s); q(s, [], { foo: [String, :allow_existence_boolean] }); end
    q3('foo:"true"').should == {'foo'=>/\btrue\b/}
    q3('foo:false').should == {'foo'=>{'$exists'=>false}}
    q3('foo:true').should == {'$and'=>[{'foo'=>{'$exists'=>true}}, {'foo'=>{'$ne'=>false}}]}
    q3('foo:false|foo:error').should == {'$or'=>[{'foo'=>{'$exists'=>false}},
                                                 {'foo'=>/error/mi}]}
  end

  it 'should handle compares' do
    def q2(s); q(s, ['f1'], { num1: Numeric }); end
    q2('num1<-230').should == {'num1'=>{'$lt'=>-230}}
    q2('num1<=5.20').should == {'num1'=>{'$lte'=>5.20}}
    q2('num1>0').should == {'num1'=>{'$gt'=>0}}
    q2('0<num1').should == {'num1'=>{'$gt'=>0}}
    q2('-5>=num1').should == {'num1'=>{'$lte'=>-5}}
    q2('num1>=1000').should == {'num1'=>{'$gte'=>1000}}
  end

  it 'should handle time compares' do
    def q2(s); q(s, [], { created: Time }); end
    q2('created<8/8/8888').should == {'created'=>{'$lt'=>Chronic.parse('8888-08-08 00:00:00')}}
    q2('created<=8/8/8888').should == {'created'=>{'$lte'=>Chronic.parse('8888-08-09 00:00:00')}}
    q2('created>"1/1/11 1:11pm"').should == {'created'=>{'$gt'=>Chronic.parse('2011-01-01 13:11:01')}}
    q2('created>="january 2020"').should =={'created'=>{'$gte'=>Chronic.parse('2020-01-01 00:00:00')}}
  end

  it 'should handle negating' do
    def q2(s); q(s, [:foo, :bar], { red: Numeric }); end
    q2('- -a').should == {'$or'=>[{:foo=>/a/mi}, {:bar=>/a/mi}]}
    q2('-a').should == {'$and'=>[{:foo=>{'$not'=>/a/mi}}, {:bar=>{'$not'=>/a/mi}}]}
    q2('-red:-1').should == {'red'=>{'$not'=>-1}}
    q2('-(-1 2 -abc)').should == {
      '$and'=>[{'$and'=>[{:foo=>{'$not'=>/\-1/mi}},
                         {:bar=>{'$not'=>/\-1/mi}}]},
               {'$and'=>[{:foo=>{'$not'=>/2/mi}},
                         {:bar=>{'$not'=>/2/mi}}]},
               {'$or'=>[{:foo=>/abc/mi},
                        {:bar=>/abc/mi}]}]}
  end

  it 'should return [] for empty nonsense' do
    fields = ['hello']
    q('', fields).should == {}
    q('   ', fields).should == {}
    q("   \n ", fields).should == {}
    q('()', fields).should == {}
    q(' ( ( ()) -(()  )) ', fields).should == {}
  end

  it 'should wacky inputs' do
    fields = ['hello']
    q('(-)', fields).should == {}
    q('(|)', fields).should == {}
    q(':', fields).should == {}
  end

end
