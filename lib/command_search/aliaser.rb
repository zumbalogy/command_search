module CommandSearch
  module Aliaser
    module_function

    def build_regex(str)
      head_border = '(?<=^|\s|[|(-])'
      tail_border = '(?=$|\s|[|)])'
      Regexp.new(head_border + Regexp.escape(str) + tail_border, 'i')
    end

    def opens_quote?(str)
      while str[/".*"/] || str[/'.*'/]
        mark = str[/["']/]
        str.sub(/#{mark}.*#{mark}/, '')
      end
      str[/"/] || str[/\B'/]
    end

    def alias_item(query, alias_key, alias_value)
      if alias_key.is_a?(Regexp)
        pattern = alias_key
      else
        pattern = build_regex(alias_key.to_s)
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
      head + replacement + tail
    end

    def alias(query, aliases)
      aliases.reduce(query) { |q, (k, v)| alias_item(q, k, v) }
    end
  end
end
