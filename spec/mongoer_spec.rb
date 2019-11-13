load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Mongoer do

  def q(x, fields = {})
    ast = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize!(ast)
    CommandSearch::Normalizer.normalize!(ast, fields)
    CommandSearch::Mongoer.build_query(ast)
  end

  it 'should work for basic string searches' do
    fields = { 'f1' => { type: String, general_search: true } }
    q('foo', fields).should == { "f1"=>/foo/i }
    q('red "blue green"', fields).should == { '$and' => [{'f1'=>/red/i},
                                                         {'f1'=>/\bblue\ green\b/}]}
    q('foo 1 2', fields).should == {'$and' => [{'f1'=>/foo/i},
                                             {'f1'=>/1/i},
                                             {'f1'=>/2/i}]}
    fields = {
      'f1' => { type: String, general_search: true },
      'f2' => { type: String, general_search: true }
    }
    q('red', fields).should == {'$or' => [{'f1'=>/red/i},
                                        {'f2'=>/red/i}]}
    q('"red"', fields).should == {'$or' => [{'f1'=>/\bred\b/},
                                          {'f2'=>/\bred\b/}]}
    q('foo "blue green"', fields).should == {
      '$and' => [{'$or' => [{'f1'=>/foo/i},
                        {'f2'=>/foo/i}]},
               {'$or' => [{'f1'=>/\bblue\ green\b/},
                        {'f2'=>/\bblue\ green\b/}]}]}
    q('foo 1 2', fields).should == {
      '$and' => [{'$or' => [{'f1'=>/foo/i},
                        {'f2'=>/foo/i}]},
               {'$or' => [{'f1'=>/1/i},
                        {'f2'=>/1/i}]},
               {'$or' => [{'f1'=>/2/i},
                        {'f2'=>/2/i}]}]}
  end

  it 'should sanitize inputs' do
    def q2(s); q(s, { f1: { type: String, general_search: true }, str1: String }); end
    q2('"a b"').should == { 'f1' => /\ba\ b\b/ }
    q2("str1:'a-b'").should == { 'str1' => /\ba\-b\b/ }
    q2("str1:'a+'").should == { 'str1' => /(^|\s|[^:+\w])a\+($|\s|[^:+\w])/ }
  end

  it 'should handle numeric type general fields' do
    def q2(s); q(s, { foo: { type: Numeric, general_search: true }, bar: { type: String, general_search: true } }); end
    q2('4').should == { '$or' => [{ 'foo' => 4.0 },
                                  { 'bar' => /4/i }] }
    q2('-(4)').should == { '$nor' => [{ 'foo' => 4.0 },
                                      { 'bar' => /4/i }]}
    def q3(s); q(s, { foo: { type: Integer, general_search: true }, bar: { type: String, general_search: true } }); end
    q3('4').should == q2('4')
    q3('-(4)').should == q2('-(4)')
    def q4(s); q(s, { foo: { type: Numeric, general_search: true, allow_existence_boolean: true }, bar: { type: String, general_search: true } }); end
    q4('4').should == q2('4')
    q4('-(4)').should == q2('-(4)')
  end

  it 'should handle ORs' do
    fields = {
      'f1' => { type: String, general_search: true },
      'f2' => { type: String, general_search: true }
    }
    q('a|b|(c|d) foo|bar', fields).should == {
      '$and' => [
        {'$or' => [
           { 'f1' => /a/i },
           { 'f2' => /a/i },
           { 'f1' => /b/i },
           { 'f2' => /b/i },
           { 'f1' => /c/i },
           { 'f2' => /c/i },
           { 'f1' => /d/i },
           { 'f2' => /d/i }] },
        { '$or' => [
           { 'f1' => /foo/i },
           { 'f2' => /foo/i },
           { 'f1' => /bar/i },
           { 'f2' => /bar/i }] }] }
  end

  # TODO: test having no type and just having it listed as general search

  it 'should denest parens' do
    fields = {
      'f1' => { type: String, general_search: true },
      'f2' => { type: String, general_search: true }
    }
    q('(a b) | (c d)', fields).should == {
      '$or' => [
        {'$and' => [
           {'$or'=>[{'f1'=>/a/i}, {'f2'=>/a/i}]},
           {'$or'=>[{'f1'=>/b/i}, {'f2'=>/b/i}]}]},
        {'$and' => [
           {'$or'=>[{'f1'=>/c/i}, {'f2'=>/c/i}]},
           {'$or'=>[{'f1'=>/d/i}, {'f2'=>/d/i}]}]}]}
  end

  it 'should handle basic commands' do
    def q2(s); q(s, { str1: String, num1: Numeric }); end
    q2('str1:red').should == { 'str1' => /red/i }
    q2('str1:12.2').should == { 'str1' => /12\.2/i }
    q2('num1:-230').should == { 'num1' => -230.0 }
    q2('num1:-0.930').should == { 'num1' => -0.930 }
    q2('num1:4.0').should == { 'num1' => 4.0 }
    q2('num1:red').should == { 'num1' => 'red' }
  end

  it 'should handle chained commands' do
    def q2(s); q(s, { f1: { type: String, general_search: true }, str1: String, num1: Numeric }); end
    q2('str1:b').should == {'str1'=>/b/i}
    q2('str1:b:c').should == {'$and' => [{'str1'=>/b/i}, {'f1'=>/b:c/i}]}
  end

  it 'should handle time commands' do
    def q2(s); q(s, { created: Time }); end
    def q3(s); q(s, { created: Date }); end
    def q4(s); q(s, { created: DateTime }); end
    res = q2('created:yesterday')
    start = res['$and'].first['created']['$gte']
    stop = res['$and'].last['created']['$lt']
    (stop - start).should == (60 * 60 * 24)
    q2('created:"april 10 2000"').should == q3('created:"april 10 2000"')
    q2('created:"april 10 2000"').should == q4('created:"april 10 2000"')
    q2('created:"april 10 2000"').should == {
      '$and' => [
        {'created'=>{'$gte'=>Chronic.parse('2000-04-10 00:00:00')}},
        {'created'=>{'$lt'=>Chronic.parse('2000-04-11 00:00:00')}}]}
    q2('-created:"april-10.2000"').should == {
      '$nor' => [{'$and' => [{'created'=>{'$gte'=>Chronic.parse('2000-04-10 00:00:00')}},
                         {'created'=>{'$lt'=>Chronic.parse('2000-04-11 00:00:00')}}]}]}
  end

  it 'should handle boolean commands' do
    def q1(s); q(s, { b: Boolean }); end
    q1('b:true').should == {'$and'=>[{'b'=>{'$exists'=>true}}, {'b'=>{'$ne'=>false}}]}
    q1('b:false').should == {'$and'=>[{'b'=>{'$exists'=>true}}, {'b'=>{'$ne'=>true}}]}
    def q2(s); q(s, { foo: { type: String, allow_existence_boolean: true } }); end
    q2('foo:"true"').should == {'foo'=>/\btrue\b/}
    q2('foo:false').should == {'foo'=>{'$exists'=>false}}
    q2('foo:true').should == {'$and' => [{'foo'=>{'$exists'=>true}},
                                       {'foo'=>{'$ne'=>false}}]}
    q2('foo:false|foo:error').should == {'$or' => [{'foo'=>{'$exists'=>false}},
                                                 {'foo'=>/error/i}]}
  end

  it 'should handle compares' do
    def q2(s); q(s, { num1: Numeric }); end
    q2('num1<-230').should == {'num1'=>{'$lt'=> -230.0 }}
    q2('num1<=5.20').should == {'num1'=>{'$lte'=>5.20}}
    q2('num1>0').should == {'num1'=>{'$gt'=>0.0}}
    q2('0<num1').should == {'num1'=>{'$gt'=>0.0}}
    q2('-5>=num1').should == {'num1'=>{'$lte'=>-5.0}}
    q2('num1>=1000').should == {'num1'=>{'$gte'=>1000.0}}
  end

  it 'should handle time compares' do
    def q2(s); q(s, { created: { type: Time } }); end
    q2('created<8/8/8888').should == {'created'=>{'$lt'=>Chronic.parse('8888-08-08 00:00:00')}}
    q2('created<=8/8/8888').should == {'created'=>{'$lte'=>Chronic.parse('8888-08-08 23:59:59')}}
    q2('created>"1/1/11 1:11pm"').should == {'created'=>{'$gt'=>Chronic.parse('2011-01-01 13:11:00')}}
    q2('created>"1/1/11 2:11pm"').should == {'created'=>{'$gt'=>Chronic.parse('2011-01-01 14:11:00')}}
    q2('created<"1:11pm"').should == {'created'=>{'$lt'=>Chronic.parse('1:11pm', guess: nil).first}}
    q2('created>="january 2020"').should =={'created'=>{'$gte'=>Chronic.parse('2020-01-01 00:00:00')}}
    def q3(s); q(s, { created: Date }); end
    q3('created<8/8/8888').should == {'created'=>{'$lt'=>Chronic.parse('8888-08-08 00:00:00')}}
    q3('created>"1/1/11 1:11pm"').should == {'created'=>{'$gt'=>Chronic.parse('2011-01-01 13:11:00')}}
    def q4(s); q(s, { created: DateTime }); end
    q4('created<8/8/8888').should == {'created'=>{'$lt'=>Chronic.parse('8888-08-08 00:00:00')}}
    q4('created>"1/1/11 1:11pm"').should == {'created'=>{'$gt'=>Chronic.parse('2011-01-01 13:11:00')}}
  end

  it 'should handle negating' do
    def q2(s)
      q(
        s,
        {
          red: { type: Numeric },
          blue: { type: String },
          foo: { type: String, general_search: true },
          bar: { type: String, general_search: true }
        }
      )
    end
    q2('a').should == { '$or' => [{ 'foo' => /a/i }, { 'bar' => /a/i }] }
    q2('- -a').should == { '$or' => [{ 'foo' => /a/i }, { 'bar' => /a/i }] }
    q2('-a').should == { '$nor' => [{ 'foo' => /a/i }, { 'bar' => /a/i }] }
    q2('-blue:"very green"').should == { '$nor' => [{ 'blue' => /\bvery\ green\b/ }] }
    q2('-red:-1').should == { '$nor' => [{ 'red' => -1.0 }] }
    q2('-red:0').should == { '$nor' => [{ 'red' => 0.0 }] }
    q2('-red:1').should == { '$nor' => [{ 'red' => 1.0 }] }
    q2('-red:66').should == { '$nor' => [{ 'red' => 66.0 }] }
    q2('1 -2 abc').should == {
      "$and" => [{ "$or" => [{ 'foo' => /1/i },
                             { 'bar' => /1/i }] },
                 { "$or" => [{ 'foo' => /\-2/i },
                             { 'bar' => /\-2/i }]},
                 { "$or" => [{ 'foo' => /abc/i },
                             { 'bar' => /abc/i }] }] }
    q2('-(-1 2 -abc)').should == {
      '$nor' => [{ '$and' => [{ '$or' => [{ 'foo' => /\-1/i }, { 'bar' => /\-1/i }] },
                              { '$or' => [{ 'foo' => /2/i }, { 'bar' => /2/i }] },
                              { '$nor' => [{ 'foo' => /abc/i },
                                           { 'bar' => /abc/i }] }] }] }
    q2('-(red:1 blue:foo) red:1').should == {
      '$and' => [{ '$nor' => [{ '$and' => [{ 'red' => 1.0 },
                                           { 'blue' => /foo/i }] }] },
                 {'red' => 1.0 }] }
  end

  it 'should handle negating with ORs' do
    def q2(s); q(s, [], { foo: String }); end
    def q2(s); q(s, { foo: { type: String } }); end
    q2('-(foo:a|foo:b)').should == { '$nor' => [{ 'foo' => /a/i },
                                                { 'foo' => /b/i }] }
    q2('-(foo:a|foo:b foo:c)').should == { '$nor' => [{ '$and' => [{ '$or' => [{ 'foo' => /a/i },
                                                                               { 'foo' => /b/i }] },
                                                                   { 'foo' => /c/i }] }] }
  end

  it 'should handle nested ORs' do
    def q2(s); q(s, { foo: { type: String }, bar: { type: String } }); end
    q2('(foo:a bar:x|bar:y)').should == {
      '$and' => [{ 'foo' => /a/i },
                 { '$or' => [{ 'bar' => /x/i },
                             { 'bar' => /y/i }] }] }
    q2('(foo:a bar:x|bar:y)|foo:b').should == {
      '$or' => [{ '$and' => [{ 'foo' => /a/i },
                             { '$or' => [{ 'bar' => /x/i },
                                         { 'bar' => /y/i }] }] },
                { 'foo' => /b/i }] }
  end

  it 'should return [] for empty nonsense' do
    fields = { 'hello' => { type: String, general_search: true } }
    q('', fields).should == {}
    q('   ', fields).should == {}
    q("   \n ", fields).should == {}
    q('()', fields).should == {}
    q(' ( ( ()) -(()  )) ', fields).should == {}
  end

  it 'should wacky inputs' do
    fields = { command: { type: String } , 'hello' => { type: String, general_search: true } }
    q('(-)', fields).should == {}
    q('(|)', fields).should == {}
    q(':', fields).should == { 'hello' => /:/i }
    q('name:foo tile -(foo bar)|"hello world" foo>1.2', fields).should_not == {}
    q('-(a)|"b"', fields).should == { '$or' => [{ '$nor' => [{ 'hello' => /a/i }] }, { 'hello' => /\bb\b/ }] }
    q('command:""', fields).should == { 'command'=> '' }
  end
end
