module CommandSearch
  module Optimizer
    module_function

    def denest!(ast, parent_type = :paren)
      ast.map! do |node|
        next [] if node[:type] == :quoted_str && node[:value] == '' && [:paren, :pipe, :minus].include?(parent_type)
        type = node[:nest_type]
        next node unless type
        next node unless type == :paren || type == :pipe || type == :minus
        denest!(node[:value], type)
        next [] if node[:value] == []
        if type == :minus
          only_child = node[:value].count == 1
          child = node[:value].first
          next child[:value] if only_child && child[:nest_type] == :minus
          next node
        end
        next node[:value] if node[:value].count == 1
        next node[:value] if type == parent_type
        next node[:value] if type == :paren && parent_type == :minus
        next node if type == :paren
        denest!(node[:value], type) # type == :pipe, parent_type == :paren
        node[:value].uniq!
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
