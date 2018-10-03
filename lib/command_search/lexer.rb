module CommandSearch
  module Lexer
    module_function

    # This class takes a string and returns it tokenized into
    # atoms/words, along with their type. It is coupled to the
    # parser in names of char_types and output data structure.

    # This currently does not support numbers with commas in them

    def char_type(char)
      case char
      when /[\"\']/
        :quote
      when /[\(\)]/
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

    def group_pattern(input, group_type, pattern)
      out = input
      len = pattern.count
      while (out.map { |x| x[:type] }).each_cons(len).find_index(pattern)
        i = (out.map { |x| x[:type] }).each_cons(len).find_index(pattern)
        span = i..(i + len - 1)
        val = out[span].map { |x| x[:value] }.join()
        out[span] = { type: group_type, value: val }
      end
      out
    end

    def full_tokens(char_token_list)
      out = char_token_list.clone

      out = group_quoted_strings(out)

      out = group_pattern(out, :pipe,    [:pipe,    :pipe])
      out = group_pattern(out, :compare, [:compare, :equal])

      out = group_pattern(out, :number,  [:number,  :period, :number])
      out = group_pattern(out, :number,  [:number,  :number])
      out = group_pattern(out, :number,  [:minus,   :number])

      out = group_pattern(out, :str,     [:equal])
      out = group_pattern(out, :str,     [:period])
      out = group_pattern(out, :str,     [:number,  :str])
      out = group_pattern(out, :str,     [:number,  :minus])
      out = group_pattern(out, :str,     [:str,     :number])
      out = group_pattern(out, :str,     [:str,     :minus])
      out = group_pattern(out, :str,     [:str,     :str])

      out = out.reject { |x| x[:type] == :space }
      out
    end

    def lex(input)
      char_tokens = input.split('').map(&method(:char_token))
      full_tokens(char_tokens)
    end
  end
end
