require('benchmark')

load(__dir__ + '/../lib/command_search/lexer.rb')
load(__dir__ + '/../lib/command_search/parser.rb')
load(__dir__ + '/../lib/command_search/command_dealiaser.rb')

$iterations = 1000

Benchmark.bmbm() do |bm|
  $bm = bm

  def dealias(input, command_fields)
    lexed = CommandSearch::Lexer.lex(input)
    parsed = CommandSearch::Parser.parse!(lexed)
    $bm.report("Decompose: #{input.inspect}") { $iterations.times {
      CommandSearch::CommandDealiaser.decompose_unaliasable(parsed, command_fields)
    } }
    $bm.report('Dealias') { $iterations.times {
      CommandSearch::CommandDealiaser.dealias(parsed, command_fields)
    } }
  end

  dealias('', {})
  dealias('foo:bar', { foo: String })
  dealias('foo:bar', { foo: :abc, abc: String })
  dealias('foo:bar ' * 10, { foo: String })
  dealias('foo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  dealias('fo:bar ' * 10, { foo: :abc, abc: :xyz, xyz: String })
  dealias('fo:bar ' * 10, { })
  dealias('fo:bar a:a b:b c:c ' * 1, { })
  dealias('fo:bar a:a b:b c:c ' * 2, { })
  dealias('fo:bar a:a b:b c:c ' * 4, { })

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
  dealias('fo:bar a:a b:b c:c ' * 2, aliases)
end
