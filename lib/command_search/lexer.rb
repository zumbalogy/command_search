module CommandSearch
  module Lexer
    module_function

    def lex(input)
      out = []
      i = 0
      while i < input.length
        match = nil
        case input[i..-1]
        when /^\s+/
          type = :space
        when /^"(.*?)"/
          match = Regexp.last_match[1]
          type = :quoted_str
        when /^'(.*?)'/
          match = Regexp.last_match[1]
          type = :quoted_str
        when /^\-?\d+(\.\d+)?(?=$|[\s"':|<>()])/
          type = :number
        when /^-/
          type = :minus
        when /^[^\s:"|<>()]+/
          type = :str
        when /^\|+/
          type = :pipe
        when /^[()]/
          type = :paren
        when /^:/
          type = :colon
        when /^[<>]=?/
          type = :compare
        when /^./
          type = :str
        end
        match = match || Regexp.last_match[0]
        out.push(type: type, value: match)
        i += Regexp.last_match[0].length
      end
      out
    end
  end
end
