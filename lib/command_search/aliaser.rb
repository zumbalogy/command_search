aliases = [
  'red' => 'blue',
  'hello world' => 'hello earth',
  'A+' => 'grade>=97',
  # 'user:me' => -> (match) { "user:#{current_user_id}" },
  # /minutes:\d+/ => -> (match) { "seconds:#{match.split(':').last.to_i * 60}" },
  # /up/i => -> 'down'
]

def opens_quote?(str)
  while str[/".*"/] || str[/'.*'/]
    mark = str[/["']/]
    str.sub(/#{mark}.*#{mark}/, '')
  end
  return str[/"/] || str[/\B'/]
end

def alias_item(query, alias_key, alias_value)
  if alias_key.is_a?(Regexp)
    pattern = alias_key
  else
    pattern = /\b#{Regexp.escape(alias_key.to_s)}\b/i
  end
  current_match = query[pattern]
  return query unless current_match
  offset = Regexp.last_match.offset(0)
  head = query[0...offset.first]
  tail = alias_item(query[offset.last..-1], alias_key, alias_value)
  if opens_quote?(head)
    replacement = current_match
  else
    if alias_value.is_a?(String)
      replacement = alias_value
    elsif alias_value.is_a?(Proc)
      replacement = alias_value.call(current_match)
    end
  end
  return head + replacement + tail
end


q = "what you talyouking about you?"
puts alias_item(q, "you", proc {|c| c + rand.to_s})



module CommandSearch
  module Aliaser
    module_function



    def alias(query, aliases)
      out = query
      aliases.each do |alias_key, alias_value|
        out = alias_item(out, alias_key, alias_value)
      end
      out
    end
  end
end
