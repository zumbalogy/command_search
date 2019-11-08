module CommandSearch
  module Optimizer
    module_function

    def denest!(ast, parent_type = :and)
      ast.map! do |node|
        next [] if node[:type] == :quoted_str && node[:value] == '' && [:and, :or, :not].include?(parent_type)
        type = node[:nest_type]
        next node unless type
        next node unless type == :and || type == :or || type == :not
        denest!(node[:value], type)
        next [] if node[:value] == []
        if type == :not
          only_child = node[:value].count == 1
          child = node[:value].first
          next child[:value] if only_child && child[:nest_type] == :not
          next node
        end
        next node[:value] if node[:value].count == 1
        next node[:value] if type == parent_type
        next node[:value] if type == :and && parent_type == :not
        next node if type == :and
        denest!(node[:value], type) # type == :or, parent_type == :and
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
