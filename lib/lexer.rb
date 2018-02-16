class Lexer
  class << self

    def char_type(char)
      case char
      when /[\"|\']/
        :quote
      when /[\(|\)]/
        :paren
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
      when '|'
        :pipe
      else
        :char
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

    def full_tokens(char_token_list)
      out = char_token_list.clone()

      while type_indices(:quote, out).length >= 2
        (a, b) = type_indices(:quote, out).first(2)
        sub = out[a..b]
        vals = sub.map { |i| i[:value] }
        out[a..b] = { type: :quoted_str, value: vals.join() }
      end

      # while consecutive(type_indices(:space, out)).any?
      #   is = consecutive(type_indices(:space, out)).first
      #   val = is.map { |i| out[i][:value] }.join()
      #   out[is.first..is.last] = { type: :space, value: val }
      # end

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

      while (out.map { |x| x[:type] }).each_cons(2).find_index([:minus, :number])
        i = (out.map { |x| x[:type] }).each_cons(2).find_index([:minus, :number])
        val = out[i..i + 1].map { |x| x[:value] }.join()
        out[i..i + 1] = { type: :number, value: val }
      end

      while consecutive(type_indices(:char, out)).any?
        is = consecutive(type_indices(:char, out)).first
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


## # some dummy test code

# str = "hello there 'sam bob    joe' -5.2 - (hello the) 234 324.3

# sdf"

# puts str
# puts Lexer.lex(str)
