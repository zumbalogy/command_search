module CommandSearch
  module Optimizer
    module_function

    def ands_and_ors!(ast)
      ast.map! do |node|
        next node unless node[:nest_type] == :paren || node[:nest_type] == :pipe
        ands_and_ors!(node[:value])
        next node[:value].first if node[:value].length == 1
        node[:value] = node[:value].flat_map do |kid|
          next kid[:value] if kid[:nest_type] == :pipe
          kid
        end
        node[:value].uniq!
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
        # valid_self && (valid_parent || valid_child)
        if node[:nest_type] == :paren && (parent_type != :pipe || node[:value].count < 2)
          next node[:value]
        end
        node
      end
    end

    def remove_empty_strings(ast)
      ast.reject! do |node|
        remove_empty_strings(node[:value]) if node[:nest_type]
        node[:type] == :quoted_str && node[:value] == ''
      end
    end

    def optimize(ast)
      out = ast
      out = denest_parens(out)
      out = negate_negate(out)
      remove_empty_strings(out)
      ands_and_ors!(out)
      out.uniq!
      out
    end
  end
end
