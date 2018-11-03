module CommandSearch
  module Lexer
    module_function

    WORD = '[^\s"|<>()]+'

    def lex(input)
      out = []
      i = 0
      while i < input.length
        match = nil
        case input[i..-1]
        when /^\s+/
          i += Regexp.last_match[0].length
          next
        when /^"(.*?)"/
          match = Regexp.last_match[1]
          type = :quoted_str
        when /^'(.*?)'/
          match = Regexp.last_match[1]
          type = :quoted_str
        when /^\-?\d+(\.\d+)?(?=$|[\s"'|<>()])/
          type = :number
        when /^\|+/
          type = :pipe
        when /^-/
          type = :minus
        when /^[()]/
          type = :paren
        when /^[<>]=?(#{WORD})/
          match = Regexp.last_match[1]
          type = :compare
        when /^:(#{WORD})/
          match = Regexp.last_match[1]
          type = :command
        when /^[^\s"|<>()]+/
          type = :str
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
