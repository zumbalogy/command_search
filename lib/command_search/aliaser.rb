module CommandSearch
  module Aliaser
    module_function

    def build_regex(str)
      head_border = '(?<=^|[^:\w])'
      tail_border = '(?=$|\W)'
      Regexp.new(head_border + Regexp.escape(str) + tail_border, 'i')
    end

    def quotes?(str, offset)
      head = str[0...offset[0]]
      tail = str[offset[1]..-1]
      return true if head.count("'").odd? && tail.count("'").odd?
      return true if head.count('"').odd? && tail.count('"').odd?
      false
    end

    def alias_item(query, alias_key, alias_value)
      return query unless alias_value.is_a?(String) || alias_value.is_a?(Proc)
      if alias_key.is_a?(Regexp)
        pattern = alias_key
      elsif alias_key.is_a?(String)
        pattern = build_regex(alias_key)
      else
        return query
      end
      query.gsub(pattern) do |match|
        next match if quotes?(query, Regexp.last_match.offset(0))
        if alias_value.is_a?(String)
          alias_value
        elsif alias_value.is_a?(Proc)
          alias_value.call(match).to_s
        end
      end
    end

    def alias(query, aliases)
      aliases.reduce(query) { |q, (k, v)| alias_item(q, k, v) }
    end
  end
end
