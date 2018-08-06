require('chronic')

class Memory
  class << self

    def check(item, ast, fields, command_types)
      field_vals = fields.map { |x| item[x] }.compact
      ast.all? do |node|
        val = node[:value]
        if node[:nest_type] == :colon
          # make it indiffernt access
          cmd = val[0][:value].to_sym
          cmd_search = val[1][:value]
          cmd_type = command_types[cmd]
          if item.key?(cmd)
            if cmd_type == Boolean
              if cmd_search == 'true'
                item[cmd]
              else
                item[cmd] == false
              end
            elsif val[1][:type] == :str
              item[cmd][/#{Regexp.escape(cmd_search)}/mi]
            else
              item[cmd][/\b#{Regexp.escape(cmd_search)}\b/]
            end
          end
        elsif node[:type] == :quoted_str
          field_vals.any? { |x| x[/\b#{Regexp.escape(val)}\b/]}
        else
          field_vals.any? { |x| x[/#{Regexp.escape(val)}/mi] }
        end
      end
    end

    def build_query(ast, fields, command_types = {})
      proc { |x| check(x, ast, fields, command_types) }
    end
  end
end
