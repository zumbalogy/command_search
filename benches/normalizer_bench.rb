require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips() do |bm|
  $bm = bm

  def norm(input, command_fields)
    ast = CommandSearch::Lexer.lex(input)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize!(ast)
    $bm.report(input.inspect) {
      ast2 = Marshal.load(Marshal.dump(ast))
      CommandSearch::Normalizer.normalize!(ast2, [:nnn, :mmm], command_fields)
    }
  end

  norm('', {})
  norm('foo:bar', { foo: String })
  norm('foo:bar', { foo: :abc, abc: String })
  norm('foo:bar ' * 10, { foo: String })
  norm('foo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  norm('fo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  norm('fo:bar ' * 10, { })
  norm('fo:bar a:a b:b c:c ' * 1, { })
  norm('fo:bar a:a b:b c:c ' * 2, { })
  norm('fo:bar a:a b:b c:c ' * 4, { })

  aliases = {
    a: '18',  b: '%',   c: 'X',
    d: '[',   e: '1F',  f: '17',
    g: ')',   h: '3',   i: '0F',
    j: '8',   k: '19',  l: 'N',
    m: '13',  n: '\b',  o: ' ',
    p: '10',  q: '00',  r: '`',
    s: '1D',  t: 'W',   u: '=',
    v: '1',   w: 'N',   x: '06',
    y: '17',  z: '#',   a2: '10',
    b2: '?',  c2: '#',  d2: '7',
    e2: 'c',  f2: '03', g2: '10',
    h2: '\t', i2: '16', j2: '1A',
    k2: '?',  l2: 'D',  m2: '`',
    n2: '\r', o2: ']',  p2: 'b',
    q2: '1D', r2: '15', s2: '\a',
    t2: '5',  u2: '(',  v2: '5',
    w2: 'S',  x2: '1D', y2: '0F',
    z2: 'zzz'
  }
  norm('fo:bar a:a b:b c:c ' * 2, aliases)
  norm('fo:bar a:a b:b c<4 ' * 2, aliases)
  norm('fo:bar a<b b<=34 c<4 ' * 2, aliases)
end
