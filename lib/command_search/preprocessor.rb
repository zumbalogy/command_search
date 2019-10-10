module CommandSearch
  module Preprocessor
    module_function

    def negation!(ast, level = 0)
      ast.map! do |node|
        type = node[:nest_type]

        if level.odd?
          if !type || type == :colon
            node[:negate] = true
            next node
          end
          if type == :compare
            flip = {
              '>' => '<=',
              '<' => '>=',
              '>=' => '<',
              '<=' => '>'
            }
            node[:nest_op] = flip[node[:nest_op]]
            next node
          end
        end

        next node unless type

        if type == :paren
          negation!(node[:value], level)
          if level.odd?
            new_val = {
              type: :nest,
              nest_type: :pipe,
              value: node[:value]
            }
            next new_val
          else
            next node
          end
        end

        if type == :pipe
          negation!(node[:value], level)
          if level.odd?
            new_val = {
              type: :nest,
              nest_type: :paren,
              value: node[:value]
            }
            next new_val
          else
            next node
          end
        end

        if type == :minus
          if level.even?
            if node[:value].count == 1
              next negation!(node[:value], level + 1)
            else
              negation!(node[:value], level + 1)
              new_val = {
                type: :nest,
                nest_type: :pipe,
                nest_op: '|',
                value: node[:value]
              }
              next new_val
            end
          else
            next negation!(node[:value], level + 1)
          end
        else
          negation!(node[:value], level)
          next node
        end
      end
      ast.flatten!
      ast
    end


    def sql_preprocess(ast, fields, command_fields)
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
