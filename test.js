const eq = (x, y) => {
  let out = true
  x.forEach((_, i) => {if (x[i] !== y[i]) out = false })
  y.forEach((_, i) => {if (x[i] !== y[i]) out = false })
  return out
}

const list = [
  'z +',
  'zz a',
  'zzz a+',
  'y a++',
  'y a++ y',
  'yy +a',
  'yyy +a+',
  'q a+a',
  'qq a+a',
  '(b+)'
]

// const foo = (str) => {
//   return list.filter(item => {
//     return item.includes(str)
//   })
// }
//

const foo = (str) => {
  return list.filter(item => {
    const head = '[^+a]'
    const tail = '$'
    return item.match(new RegExp(head + str.replace('+', '\+') + tail))
  })
}

console.log(foo('a'))

if (!eq(foo('a'),   ['zz a']))            { throw '1' }
if (!eq(foo('a+'),  ['zzz a+']))          { throw '2' }
if (!eq(foo('+a+'), ['yyy +a+']))         { throw '3' }
if (!eq(foo('a+a'), ['q a+a', 'qq a+a'])) { throw '4' }
// if (!eq(foo('a++'), ['y a++', 'a++ y']))  { throw '5' }
if (!eq(foo('b+'),  ['(b+)']))            { throw '6' }
