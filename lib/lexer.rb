class Lexer

  # This class takes a string and returns it tokenized into
  # atoms/words, along with their type. It is coupled to the
  # parser in names of char_types and output data structure.

  # This currently does not support numbers with commas in them
  class << self

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

    def value_indices(match, lst)
      lst.each_index.select { |i| lst[i][:value] == match }
    end

    def group_quoted_string(input, str_type)
      out = input
      while value_indices(str_type, out).length >= 2
        (a, b) = value_indices(str_type, out).first(2)
        vals = out[a..b].map { |i| i[:value] }
        trimmed_vals = vals.take(vals.length - 1).drop(1)
        # this should make sure to eat up any inner nested quotes.
        # by flattening out the trimmed values.
        # also I want ("hello'"' there") to be a total single quote i guess.
        out[a..b] = { type: :quoted_str, value: trimmed_vals.join() }
      end
      out
    end

    def group_pattern(input, group_type, pattern)
      out = input
      len = pattern.count
      while (out.map { |x| x[:type] }).each_cons(len).find_index(pattern)
        i = (out.map { |x| x[:type] }).each_cons(len).find_index(pattern)
        val = out[i..i + (len - 1)].map { |x| x[:value] }.join()
        out[i..i + (len - 1)] = { type: group_type, value: val }
      end
      out
    end

    def full_tokens(char_token_list)
      out = char_token_list.clone()

      out = group_quoted_string(out, "'")
      out = group_quoted_string(out, '"')

      out = group_pattern(out, :number,  [:number,  :number])
      out = group_pattern(out, :number,  [:number,  :period, :number])
      out = group_pattern(out, :str,     [:str,     :minus,  :str])
      out = group_pattern(out, :compare, [:compare, :equal])
      out = group_pattern(out, :number,  [:minus,   :number])
      out = group_pattern(out, :str,     [:str,     :number])
      out = group_pattern(out, :str,     [:number,  :str])
      out = group_pattern(out, :str,     [:str,     :str])

      out = out.reject { |x| x[:type] == :space }
      out
    end

    def lex(input)
      char_tokens = input.split('').map(&method(:char_token))
      tokens = full_tokens(char_tokens)
    end
  end
end
