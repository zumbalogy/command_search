module CommandSearch
  module Preprocessor
    module_function

    def negation!(ast, level = 0)
      ast.map! do |node|
        type = node[:nest_type]

        if level.odd?
          node[:negate] = true if !type || type == :colon
          if type == :compare
            flip = {
              '>' => '<=',
              '<' => '>=',
              '>=' => '<',
              '<=' => '>'
            }
            node[:nest_op] = flip[node[:nest_op]]
          end
        end

        if type == :minus
          negation!(node[:value], level + 1)
          next node[:value] if level.odd? || node[:value].count == 1
          next {
            type: :nest,
            nest_type: :pipe,
            nest_op: '|',
            value: node[:value]
          }
        end

        next node unless type == :paren || type == :pipe
        negation!(node[:value], level)
        next node if level.even?
        {
          type: :nest,
          value: node[:value],
          nest_type: (type == :paren ? :pipe : :paren)
        }
      end
      ast.flatten!
      ast
    end


    def sql_preprocess!(ast)
      negation!(ast)
      ast.map! do |node|
        next node[:value] if node[:nest_type] == :paren
        next node
      end
      ast.flatten!
      ast
    end
  end
end
