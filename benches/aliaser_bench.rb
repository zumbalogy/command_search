require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips do |bm|
  $bm = bm
  bm.time = 2
  bm.warmup = 0.2

  def bench(input, aliases)
    $bm.report(input.inspect[0..24]) do
      aliased = CommandSearch::Aliaser.alias(input, aliases)
    end
  end

  bench('', {})
  bench('', { 'foo' => 'bar' })

  bench('foo bar', { 'foo' => 'bar' })
  bench('foo bar', { 'foo' => 'bar', 'bar' => 'abc' })
  bench('foo bar', { 'foo' => 'bar', 'a' => 'b', 'b' => 'c', 'c' => 'd' })

  bench('foo fn', { 'fn' => -> (match) { match * 2 } })
  bench('foo fn fn', { 'fn' => -> (match) { match * 2 } })
  bench('foo fn "fn"', { 'fn' => -> (match) { match * 2 } })
  bench('foo fn "fn"' * 100, { 'fn' => -> (match) { match * 2 } })
  bench('foo fn fn1', { 'fn' => -> (match) { match * 2 } })
  bench('foo fn fn1 fn2', { 'fn' => -> (match) { match * 2 }, 'fn1' => -> (m) { m + 'ddsdf' }, 'fn2' => -> (m) { m[0] } })
end
