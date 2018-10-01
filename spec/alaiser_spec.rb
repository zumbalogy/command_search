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
# 'top scores' => -> handle conditionally sorting the output by something?

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
    a('-red').should == '-blue'
    a('(red)').should == '(blue)'
    a('(-red)').should == '(-blue)'
    a('A+').should == 'grade>=97'
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
    a('cool', { /oo/ => 'ooo', /ooo/ => '__' }).should == 'c__l'
  end

  it 'should handle function aliases with closures' do
    skip 'TODO'
  end

end

# TODO: make sure it plays friendly with pagination and all for mongo and
# in memory. pretty sure it should and all, (for in memory it could just be they stream
# things into commandSearch in chunks until they hit a quota or run out) but maybe it would
# be best to have an example in the readme

# TODO: note that the query passed to the next alias proc be the modyfied query

# TODO: make sure to test having multiple matches in one query

# TODO: put a note in the readme about how this is all
# case sensitive (or if its not) and happens outside of quoted
# parts of the query and how one can just do transformations
# before sending it to commandSearch if wanting to live more
# dangerously and all. and how it deals with word boundry for strings,
# and "bab" only matches "babab" once.

# TODO: for sorting example:

# hats = [{foo: 1, bar: 20}, {foo: 10, bar: 15}, {foo: 100, bar: 10}]
#
# def self.search(query)
#   sorter = 'foo' # maybe needs to be global var
#   sortFn = -> (match, _q) { sorter = match.split(':').last; return '' }
#   found_hats = CommandSearch.search(hats, query, {foo: [/sort:\w+/ => sortFn]})
#   hats.sort_by {|x| x[:sorter]}
# end
