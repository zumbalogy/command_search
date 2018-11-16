module CommandSearch
  module Aliaser

    def self.build_regex(str)
      head_border = '(?<=^|[^:\w])'
      tail_border = '(?=$|\W)'
      Regexp.new(head_border + Regexp.escape(str) + tail_border, 'i')
    end

    def self.quotes?(head, tail)
      return true if head.count("'").odd? && tail.count("'").odd?
      return true if head.count('"').odd? && tail.count('"').odd?
      false
    end

    def self.alias_item(query, alias_key, alias_value)
      if alias_key.is_a?(Regexp)
        pattern = alias_key
      elsif alias_key.is_a?(String)
        pattern = build_regex(alias_key)
      else
        return query
      end
      current_match = query[pattern]
      return query unless current_match
      offset = Regexp.last_match.offset(0)
      head = query[0...offset.first]
      tail = alias_item(query[offset.last..-1], alias_key, alias_value)
      if quotes?(head, tail)
        replacement = current_match
      else
        if alias_value.is_a?(String)
          replacement = alias_value
        elsif alias_value.is_a?(Proc)
          replacement = alias_value.call(current_match).to_s
        else
          return query
        end
      end
      head + replacement + tail
    end

    def self.alias(query, aliases)
      aliases.reduce(query) { |q, (k, v)| alias_item(q, k, v) }
    end
  end
end
