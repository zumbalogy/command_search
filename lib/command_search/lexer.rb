module CommandSearch
  module Lexer
    module_function

    def lex(input)
      out = []
      i = 0
      while i < input.length
        case input[i..-1]
        when /^"(.*?)"/
          match = Regexp.last_match[1]
          out.push(type: :quoted_str, value: match)
          i += match.length + 2
        when /^'(.*?)'/
          match = Regexp.last_match[1]
          out.push(type: :quoted_str, value: match)
          i += match.length + 2
        when /^\s+/
          match = Regexp.last_match[0]
          i += match.length
        when /^\|+/
          match = Regexp.last_match[0]
          out.push(type: :pipe, value: match)
          i += match.length
        when /^(\-?\d+(\.\d+)?)($|[\s|"':)<>])/
          match = Regexp.last_match[1]
          out.push(type: :number, value: match)
          i += match.length
        when /^-/
          match = Regexp.last_match[0]
          out.push(type: :minus, value: match)
          i += match.length
        when /^:/
          match = Regexp.last_match[0]
          out.push(type: :colon, value: match)
          i += match.length
        when /^[()]/
          match = Regexp.last_match[0]
          out.push(type: :paren, value: match)
          i += match.length
        when /^[<>]=?/
          match = Regexp.last_match[0]
          out.push(type: :compare, value: match)
          i += match.length
        when /^\d*[^\d\s"':)][^\s"'|:<>)(]*/
          match = Regexp.last_match[0]
          out.push(type: :str, value: match)
          i += match.length
        else
          out.push(type: :str, value: input[i])
          i += 1
        end
      end
      out
    end
  end
end
