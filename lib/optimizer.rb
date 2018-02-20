class Optimizer
  class << self

    def ands_and_ors(ast)
      out = ast

      or_index = out.index { |x| x[:nest_type] == :pipe }
      or_list = out.select { |x| x[:nest_type] == :pipe }
      or_values = or_list.flat_map { |x| x[:value] }
      new_or = {
        type: :nest,
        nest_type: :pipe,
        nest_op: or_list.first&[:nest_op],
        value: or_values
      }
      out = out.delete_if { |x| x[:nest_type] == :pipe }
      out = out.insert(or_index, new_or) if or_index

      out = out.uniq

      out.flat_map do |node|
        next node unless node[:nest_type]
        node[:value] = ands_and_ors(node[:value])
        next [] if node[:value] == []
        node
      end
    end

    def negate_negate(ast)
      ast.flat_map do |node|
        next node unless node[:nest_type]
        node[:value] = negate_negate(node[:value])
        next [] if node[:value] == []
        next node if node[:value].count > 1
        type = node[:nest_type]
        child_type = node[:value].first[:nest_type]
        next node unless type == :minus && child_type == :minus
        node[:value].first[:value]
      end
    end

    def denest_parens(ast, parent_type = :root)
      ast.flat_map do |node|
        next node unless node[:nest_type]
        node[:value] = denest_parens(node[:value], node[:nest_type])
        next [] if node[:value] == []
        next node unless node[:nest_type] == :paren
        valid_op = parent_type == :pipe || parent_type == :minus
        next node[:value] unless valid_op
        next node[:value] if node[:value].count < 2
        node
      end
    end

    def optimize(ast)
      out = ast
      out = denest_parens(out)
      out = negate_negate(out)
      out = ands_and_ors(out)
      out
    end
  end
end

# load('~/projects/searchable/lib/lexer.rb')
# load('~/projects/searchable/lib/parser.rb')
# require('pp')

# str = 'a -(b (c))'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c


# str = '-()'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c


# str = '(a a (a -b))'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c
