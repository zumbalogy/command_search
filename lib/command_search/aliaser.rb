module CommandSearch
  module Aliaser
    module_function

    def build_regex(str)
      head = '(?<=^|[^:\w])'
      tail = '(?=$|\W)'
      Regexp.new(head + Regexp.escape(str) + tail, 'i')
    end

    def quotes?(str, offset)
      head = str[0...offset[0]]
      tail = str[offset[1]..-1]
      return true if head.count("'").odd? && tail.count("'").odd?
      return true if head.count('"').odd? && tail.count('"').odd?
      false
    end

    def alias_item!(query, key, val)
      if key.is_a?(String) || key.is_a?(Symbol)
        key = build_regex(key)
      end
      query.gsub!(key) do |match|
        next match if quotes?(query, Regexp.last_match.offset(0))
        next val.call(match) if val.is_a?(Proc)
        val
      end
    end

    def alias(query, aliases)
      return query unless aliases.any?
      out = query.dup
      aliases.each { |(k, v)| alias_item!(out, k, v) }
      out
    end
  end
end
