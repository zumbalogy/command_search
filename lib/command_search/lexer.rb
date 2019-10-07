module CommandSearch
  module Lexer
    module_function

    def lex(input)
      out = []
      i = 0
      while i < input.length
        match = input[i]
        type = :str
        tail = input[i..-1]
        if tail.start_with?(/\s+/)
          i += Regexp.last_match[0].length
          next
        elsif tail.start_with?(/"(.*?)"/)
          i += 2
          match = Regexp.last_match[1]
          type = :quoted_str
        elsif tail.start_with?(/'(.*?)'/)
          i += 2
          match = Regexp.last_match[1]
          type = :quoted_str
        elsif tail.start_with?(/\-?\d+(\.\d+)?(?=$|[\s"':|<>()])/)
          match = Regexp.last_match[0]
          type = :number
        elsif match == '-'
          type = :minus
        elsif match == ':'
          type = :colon
        elsif tail.start_with?(/[^\s:"|<>()]+/)
          match = Regexp.last_match[0]
        elsif match == '|'
          match = tail[/\|+/]
          type = :pipe
        elsif tail.start_with?(/[()]/)
          match = Regexp.last_match[0]
          type = :paren
        elsif tail.start_with?(/[<>]=?/)
          match = Regexp.last_match[0]
          type = :compare
        end
        out.push(type: type, value: match)
        i += match.length
      end
      out
    end
  end
end


# TODO: using start_with? with a regex is only avialable as of Ruby 2.6.0	2018-12-25,  which is not great.
# but, Ruby 2.4 is now under the state of the security maintenance phase, until the end of March of 2020
