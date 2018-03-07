class Lexer

  # This class takes a string and returns it tokenized into
  # atoms/words, along with their type. It is coupled to the
  # parser only in the choice of char_types and basic output
  # data structure.

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

    def consecutive(lst)
      lst.chunk_while { |a, b| a + 1 == b }.select { |a| a.size > 1 }
    end

    def char_token(char)
      { type: char_type(char), value: char }
    end

    def type_indices(match, lst)
      lst.each_index.select { |i| lst[i][:type] == match }
    end

    def value_indices(match, lst)
      lst.each_index.select { |i| lst[i][:value] == match }
    end

    def full_tokens(char_token_list)
      out = char_token_list.clone()

      while value_indices("'", out).length >= 2
        (a, b) = value_indices("'", out).first(2)
        sub = out[a..b]
        vals = sub.map { |i| i[:value] }
        trimmed_vals = vals.take(vals.length - 1).drop(1)
        out[a..b] = { type: :quoted_str, value: trimmed_vals.join() }
      end

      while value_indices('"', out).length >= 2
        (a, b) = value_indices('"', out).first(2)
        sub = out[a..b]
        vals = sub.map { |i| i[:value] }
        trimmed_vals = vals.take(vals.length - 1).drop(1)
        out[a..b] = { type: :quoted_str, value: trimmed_vals.join() }
      end

      while consecutive(type_indices(:number, out)).any?
        is = consecutive(type_indices(:number, out)).first
        val = is.map { |i| out[i][:value] }.join()
        out[is.first..is.last] = { type: :number, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(3).find_index([:number, :period, :number])
        i = (out.map { |x| x[:type] }).each_cons(3).find_index([:number, :period, :number])
        val = out[i..i + 2].map { |x| x[:value] }.join()
        out[i..i + 2] = { type: :number, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(3).find_index([:str, :minus, :str])
        i = (out.map { |x| x[:type] }).each_cons(3).find_index([:str, :minus, :str])
        val = out[i..i + 2].map { |x| x[:value] }.join()
        out[i..i + 2] = { type: :str, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(2).find_index([:compare, :equal])
        i = (out.map { |x| x[:type] }).each_cons(2).find_index([:compare, :equal])
        val = out[i..i + 1].map { |x| x[:value] }.join()
        out[i..i + 1] = { type: :compare, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(2).find_index([:minus, :number])
        i = (out.map { |x| x[:type] }).each_cons(2).find_index([:minus, :number])
        val = out[i..i + 1].map { |x| x[:value] }.join()
        out[i..i + 1] = { type: :number, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(2).find_index([:str, :number])
        i = (out.map { |x| x[:type] }).each_cons(2).find_index([:str, :number])
        val = out[i..i + 1].map { |x| x[:value] }.join()
        out[i..i + 1] = { type: :str, value: val }
      end

      while (out.map { |x| x[:type] }).each_cons(2).find_index([:number, :str])
        i = (out.map { |x| x[:type] }).each_cons(2).find_index([:number, :str])
        val = out[i..i + 1].map { |x| x[:value] }.join()
        out[i..i + 1] = { type: :str, value: val }
      end

      while consecutive(type_indices(:str, out)).any?
        is = consecutive(type_indices(:str, out)).first
        val = is.map { |i| out[i][:value] }.join()
        out[is.first..is.last] = { type: :str, value: val }
      end

      while type_indices(:space, out).any?
        i = type_indices(:space, out).first
        out.delete_at(i)
      end

      out
    end

    def lex(input)
      char_tokens = input.split('').map(&method(:char_token))
      tokens = full_tokens(char_tokens)
    end

  end
end
