module CommandSearch
  module Optimizer
    module_function

    def ands_and_ors(ast)
      ast.uniq.map do |node|
        next node unless node[:nest_type]
        next node if node[:nest_type] == :compare
        node[:value] = ands_and_ors(node[:value])
        node[:value] = node[:value].flat_map do |kid|
          next kid[:value] if kid[:nest_type] == :pipe
          kid
        end
        if node[:nest_type] == :pipe && node[:value].length == 1
          next node[:value].first
        end
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

        valid_self = node[:nest_type] == :paren
        valid_parent = parent_type != :pipe
        valid_child = node[:value].count < 2

        next node[:value] if valid_self && valid_parent
        next node[:value] if valid_self && valid_child
        node
      end
    end

    def optimization_pass(ast)
      # '(a b)|(c d)' is the  only current
      # situation where parens are needed.
      # 'a|(b|(c|d))' can be flattened by
      # repeated application of "ands_and_or"
      # and "denest_parens".
      out = ast
      out = denest_parens(out)
      out = negate_negate(out)
      out = ands_and_ors(out)
      out
    end

    def optimize(ast)
      out_a = optimization_pass(ast)
      out_b = optimization_pass(out_a)
      until out_a == out_b
        out_a = out_b
        out_b = optimization_pass(out_b)
      end
      out_b
    end
  end
end
