module CommandSearch
  module Optimizer
    module_function

    def denest!(ast, parent_type = :root)
      ast.map! do |node|
        next [] if node[:type] == :quoted_str && node[:value] == '' && [:paren, :pipe, :minus, :root].include?(parent_type)
        type = node[:nest_type]
        next node unless type
        denest!(node[:value], node[:nest_type])
        next [] if node[:value] == []
        next node[:value] if type != :minus && node[:value].count < 2
        next node[:value] if type == :paren && parent_type != :pipe
        only_child = node[:value].count == 1
        child = node[:value].first
        next child[:value] if type == :minus && only_child && child[:nest_type] == :minus
        if type == :paren || type == :pipe
          denest!(node[:value], node[:nest_type])
          node[:value].uniq!
          next node[:value] if type == :pipe && parent_type == :pipe
        end
        node
      end
      ast.flatten!
    end

    def optimize!(ast)
      denest!(ast)
      ast.uniq!
      ast
    end
  end
end
