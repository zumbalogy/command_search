load(__dir__ + '/./spec_helper.rb')

current_user_id = '59guwJphUhqfd2A'

foos = [
  'red' => 'blue',
  'hello world' => 'hello earth',
  'A+' => 'grade>=97',
  'user:me' => -> (match, query) { "user:#{current_user_id}" },
  /minutes:\d+/ => -> (match, query) { "seconds:#{match.split(':').last.to_i * 60}" }
]
# 'top scores' => -> handle conditionally sorting the output by something?

# rches for `username:alice`, the search `A+` becomes
# `grade>=97`, or `user:me`

def foo(input)
  CommandSearch::Foo.foo(input, foos)
end

describe CommandSearch::Foo do

  it 'should handle no foos' do
    foo('', []).should == ''
    foo(' ', []).should == ' '
    foo('foo|bar -bat "" baz:zap', []).should == 'foo|bar -bat "" baz:zap'
  end

end

# TODO: make sure it plays friendly with pagination and all for mongo and
# in memory. pretty sure it should and all, (for in memory it could just be they stream
# things into commandSearch in chunks until they hit a quota or run out) but maybe it would
# be best to have an example in the readme

# TODO: what to do when a query matches multiple competing aliases?
# just resolve them in order?
# and should the query passed to the next alias proc be the modyfied query?

# TODO: make sure to test having multiple matches in one query


# TODO: put a note in the readme about how this is all
# case sensitive (or if its not) and happens outside of quoted
# parts of the query and how one can just do transformations
# before sending it to commandSearch if wanting to live more
# dangerously and all


# TODO: for sorting example:

# hats = [{foo: 1, bar: 20}, {foo: 10, bar: 15}, {foo: 100, bar: 10}]
#
# def self.search(query)
#   sorter = 'foo' # maybe needs to be global var
#   sortFn = -> (match, _q) { sorter = match.split(':').last; return '' }
#   found_hats = CommandSearch.search(hats, query, {foo: [/sort:\w+/ => sortFn]})
#   hats.sort_by {|x| x[:sorter]}
# end
