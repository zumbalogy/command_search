module CommandSearch
  module Lexer
    module_function

    def lex(input)
      out = []
      i = 0
      while i < input.length
        match = nil
        case input[i..-1]
        when /\A\s+/
          next i += Regexp.last_match[0].length
        when /\A"(.*?)"/
          match = Regexp.last_match[1]
          type = :quote
        when /\A'(.*?)'/
          match = Regexp.last_match[1]
          type = :quote
        when /\A\-?\d+(\.\d+)?(?=$|[\s"':|<>()])/
          type = :number
        when /\A-/
          type = :minus
        when /\A[^\s:|<>()]+/
          type = :str
        when /\A\|+/
          type = :pipe
        when /\A[()]/
          type = :paren
        when /\A:/
          type = :colon
        when /\A[<>]=?/
          type = :compare
        end
        match ||= Regexp.last_match[0]
        out.push(type: type, value: match)
        i += Regexp.last_match[0].length
      end
      out
    end
  end
end
