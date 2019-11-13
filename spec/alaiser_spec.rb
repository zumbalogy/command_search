load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Aliaser do

  $current_user_id = '59guwJphUhqfd2A'

  $aliases = {
    'red' => 'blue',
    'hello world' => 'hello earth',
    'A+' => 'grade>=97',
    'user:me' => -> (match) { "user:#{$current_user_id}" },
    /coo+l/ => 'ice cold',
    /minutes:\d+/ => -> (match) { "seconds:#{match.split(':').last.to_i * 60}" },
    sym_key: 'str_val',
    'str_key' => :sym_val,
    'num_key' => 123,
    'bad_key' => []
  }

  def a(input, input_aliases = $aliases)
    CommandSearch::Aliaser.alias(input, input_aliases)
  end

  it 'should handle no aliases' do
    a('', {}).should == ''
    a(' ', {}).should == ' '
    a('foo|bar -bat "" baz:zap', {}).should == 'foo|bar -bat "" baz:zap'
  end

  it 'should not modify the original string' do
    str = 'a red house'
    a(str).should == 'a blue house'
    a('a red house').should == 'a blue house'
    str.should == 'a red house'
  end

  it 'should handle text to text aliases' do
    a('aredhouse').should == 'aredhouse'
    a('a red house').should == 'a blue house'
    a('red house').should == 'blue house'
    a('redhouse').should == 'redhouse'
    a('house red').should == 'house blue'
    a('a RED house').should == 'a blue house'
    a('a Red house').should == 'a blue house'
    a('a rED house').should == 'a blue house'
    a('a reD house').should == 'a blue house'
    a('a rEd house').should == 'a blue house'
    a('aRedHouse').should == 'aRedHouse'
  end

  it 'should handle quotes' do
    a('a very red house').should == 'a very blue house'
    a('a "very red house').should == 'a "very blue house'
    a('a"very red house').should == 'a"very blue house'
    a('a very red "house').should == 'a very blue "house'
    a('a "very red" house').should == 'a "very red" house'
    a('a"very red"house').should == 'a"very red"house'
    a('a""very red"house').should == 'a""very blue"house'
    a("a 'very red' house").should == "a 'very red' house"
    a("a 'very' red house").should == "a 'very' blue house"
    a('a "very" red house').should == 'a "very" blue house'
    a("red's red house").should == "blue's blue house"
    a("red's RED house").should == "blue's blue house"
    a("a \"very\" red house's roof").should == "a \"very\" blue house's roof"

    a('a"""very red"house', { '"very' => 'light' }).should == 'a""light red"house'
    a('a""very red"house', { '"very' => 'light' }).should == 'a""very red"house'

  end

  it 'should handle aliases with command syntax' do
    a('hello world').should == 'hello earth'
    a('greeting:hello world').should == 'greeting:hello world'
    a('house:red').should == 'house:red'
    a('house:red', { /:red\b/ => ':abc' }).should == 'house:abc'
    a('red,red,red').should == 'blue,blue,blue'
    a('-red').should == '-blue'
    a('(red)').should == '(blue)'
    a('(-red)').should == '(-blue)'
    a('A+').should == 'grade>=97'
    a('yo A+ 123').should == 'yo grade>=97 123'
    a('(A+)').should == '(grade>=97)'
    a('-A+').should == '-grade>=97'
    a('A+|F-').should == 'grade>=97|F-'
    a('abc A+|F-').should == 'abc grade>=97|F-'
  end

  it 'should handle regex to text aliases' do
    a('col').should == 'col'
    a('coOl').should == 'coOl'
    a('cool').should == 'ice cold'
    a('uncool').should == 'unice cold'
    a('cooooool').should == 'ice cold'
    a('cooooool2themax').should == 'ice cold2themax'
  end

  it 'should handle text to function aliases' do
    a('user:me').should == 'user:' + $current_user_id
    a('user:Me').should == 'user:' + $current_user_id
    a('user:you').should == 'user:you'
  end

  it 'should handle regex to function aliases' do
    a('minutes:10').should == 'seconds:600'
    a('-minutes:0').should == '-seconds:0'
    a('foo bar -(minutes:2 baz)').should == 'foo bar -(seconds:120 baz)'
  end

  it 'should handle multiple matches sequentially' do
    a('foo', { 'foo' => 'bar', 'bar' => 'baz' }).should == 'baz'
    a('foo', { 'foo' => 'bar', /fo./ => 'baz' }).should == 'bar'
    a('me', { 'me' => 'current_user', 'user' => 'non_admin' }).should == 'current_user'
    a('you', { 'me' => 'self', 'you' => 'me' }).should == 'me'
    a('cool', { /oo/ => 'ooooo' }).should == 'coooool'
    a('cool', { /oo/ => 'ooo', /ooo/ => '__' }).should == 'c__l'
  end

  it 'should handle function aliases with closures' do
    variable = 0
    a('hit', { 'hit' => proc { |_| variable = 100; 101 } }).should == '101'
    variable.should == 100
    variable2 = ''
    a('abc', { /./ => proc { |x| variable2 += x; x } }).should == 'abc'
    variable2.should == 'abc'
  end

  it 'should handle having multiple matches in one query' do
    a('red red red').should == 'blue blue blue'
    a('cool cooool cooooool hot cool').should == 'ice cold ice cold ice cold hot ice cold'
    a('hello hello hello', { 'hello hello' => 'bye hello' }).should == 'bye hello hello'
    a('hello hello hello hello', { 'hello hello' => 'bye hello' }).should == 'bye hello bye hello'
  end

  it 'should handle different datatypes in aliases' do
    a('[]').should == '[]'
    a('[2]').should == '[2]'
    a('bad_key').should == '[]'
    a('num_key').should == '123'
    a('sym_key').should == 'str_val'
    a('str_key').should == 'sym_val'
  end
end
