@list = [
  'z +',
  'zz a',
  'zzz a+',
  'y a++',
  'yy +a',
  'yyy +a+',
  'q a+a'
]

def foo(str)
  return @list
end


raise unless foo('a') == ['zz a']
raise unless foo('a+') == ['zzz a+']
raise unless foo('+a+') == ['yyy a+']
raise unless foo('a+a') == ['q a+a']
