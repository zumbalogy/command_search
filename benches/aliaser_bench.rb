require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips do |bm|
  $bm = bm

  def bench(input, aliases)
    $bm.report(input.inspect[0..24]) do
      CommandSearch::Aliaser.alias(input, aliases)
    end
  end

  bench('', {})
  bench('', { 'foo' => 'bar' })

  bench('foo bar', { 'foo' => 'bar' })
  bench('foo bar', { 'foo' => 'bar', 'bar' => 'abc' })
  bench('foo bar', { 'foo' => 'bar', 'a' => 'b', 'b' => 'c', 'c' => 'd' })

  bench('foo fn',            { 'fn' => -> (m) { m * 2 } })
  bench('foo fn fn',         { 'fn' => -> (m) { m * 2 } })
  bench('foo fn "fn"',       { 'fn' => -> (m) { m * 2 } })
  bench('foo fn "fn"' * 100, { 'fn' => -> (m) { m * 2 } })
  bench('foo fn fn1',        { 'fn' => -> (m) { m * 2 } })

  bench(
    'foo fn fn1 fn2',
    {
      'fn' => -> (m) { m * 2 },
      'fn1' => -> (m) { m + 'ddsdf' },
      'fn2' => -> (m) { m[0] }
    }
  )
end
