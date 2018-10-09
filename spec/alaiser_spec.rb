load(__dir__ + '/./spec_helper.rb')

$current_user_id = '59guwJphUhqfd2A'

$aliases = {
  'red' => 'blue',
  'hello world' => 'hello earth',
  'A+' => 'grade>=97',
  'user:me' => -> (match) { "user:#{$current_user_id}" },
  /coo+l/ => 'ice cold',
  /minutes:\d+/ => -> (match) { "seconds:#{match.split(':').last.to_i * 60}" }
}

def a(input, input_aliases = $aliases)
  CommandSearch::Aliaser.alias(input, input_aliases)
end

describe CommandSearch::Aliaser do

  it 'should handle no aliases' do
    a('', {}).should == ''
    a(' ', {}).should == ' '
    a('foo|bar -bat "" baz:zap', {}).should == 'foo|bar -bat "" baz:zap'
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

  it 'should handle aliases with command syntax' do
    a('hello world').should == 'hello earth'
    a('greeting:hello world').should == 'greeting:hello world'
    a('house:red').should == 'house:red' # TODO: if this the desired way to handle colons, should then be noted somewhere/
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
    a('me', { 'me' => 'current_user', 'user' => 'non_admin' }).should == 'current_user'
    a('you', { 'me' => 'self', 'you' => 'me' }).should == 'me'
    a('cool', { /oo/ => 'ooooo' }).should == 'coooool'
    a('cool', { /oo/ => 'ooo', /ooo/ => '__' }).should == 'c__l'
  end

  it 'should handle function aliases with closures' do
    variable = 0
    a('hit', { 'hit' => proc {|_| variable = 100; 101 }}).should == '101'
    variable.should == 100
    variable2 = ''
    a('abc', { /./ => proc {|x| variable2 += x; x }}).should == 'abc'
    variable2.should == 'cba'
  end

  it 'should handle having multiple matches in one query' do
    a('red red red').should == 'blue blue blue'
    a('cool cooool cooooool hot cool').should == 'ice cold ice cold ice cold hot ice cold'
    a('hello hello hello', { 'hello hello' => 'bye hello' }).should == 'bye hello hello'
    a('hello hello hello hello', { 'hello hello' => 'bye hello' }).should == 'bye hello bye hello'
  end
end

# TODO: make sure it plays friendly with pagination and all for mongo and
# in memory. pretty sure it should and all, (for in memory it could just be they stream
# things into commandSearch in chunks until they hit a quota or run out) but maybe it would
# be best to have an example in the readme
