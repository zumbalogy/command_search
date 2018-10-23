module CommandSearch
  module Lexer
    module_function

    def char_type(char)
      case char
      when /["']/
        :quote
      when /[()]/
        :paren
      when /[<>]/
        :compare
      when /\s/
        :space
      when /\d/
        :number
      when '.'
        :period
      when '-'
        :minus
      when ':'
        :colon
      when '='
        :equal
      when '|'
        :pipe
      else
        :str
      end
    end

    def char_token(char)
      { type: char_type(char), value: char }
    end

    def value_indices(match, list)
      list.each_index.select { |i| list[i][:value] == match }
    end

    def group_quoted_strings(input)
      out = input
      while value_indices("'", out).length >= 2 || value_indices('"', out).length >= 2
        (a, b) = value_indices("'", out).first(2)
        (c, d) = value_indices('"', out).first(2)
        if a && b && (c.nil? || (a < c))
          (x, y) = [a, b]
        else
          (x, y) = [c, d]
        end
        vals = out[x..y].map { |i| i[:value] }
        trimmed_vals = vals.take(vals.length - 1).drop(1)
        out[x..y] = { type: :quoted_str, value: trimmed_vals.join }
      end
      out
    end

    def group_pattern!(input, group_type, pattern)
      len = pattern.count
      i = 0
      while i < input.length
        span = i..(i + len - 1)
        if pattern == input[span].map { |x| x[:type] }
          val = input[span].map { |x| x[:value] }.join()
          input[span] = { type: group_type, value: val }
        else
          i += 1
        end
      end
    end

    def full_tokens(char_token_list)
      out = char_token_list.clone

      out = group_quoted_strings(out)

      group_pattern!(out, :pipe,    [:pipe,    :pipe])
      group_pattern!(out, :compare, [:compare, :equal])

      group_pattern!(out, :number,  [:number,  :period, :number])
      group_pattern!(out, :number,  [:number,  :number])
      group_pattern!(out, :number,  [:minus,   :number])

      group_pattern!(out, :str,     [:equal])
      group_pattern!(out, :str,     [:period])
      group_pattern!(out, :str,     [:number,  :str])
      group_pattern!(out, :str,     [:number,  :minus])
      group_pattern!(out, :str,     [:str,     :number])
      group_pattern!(out, :str,     [:str,     :minus])
      group_pattern!(out, :str,     [:str,     :str])

      out = out.reject { |x| x[:type] == :space }
      out
    end

    def lex(input)
      char_tokens = input.split('').map(&method(:char_token))
      full_tokens(char_tokens)
    end
  end
end
