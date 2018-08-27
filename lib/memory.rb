require('chronic')

class Memory
  class << self

    def command_check(item, val, command_types)
      cmd = val[0][:value].to_sym
      cmd_search = val[1][:value]
      raw_cmd_type = [command_types[cmd]].flatten
      allow_existence_boolean = raw_cmd_type.include?(:allow_existence_boolean)
      cmd_type = (raw_cmd_type - [:allow_existence_boolean]).first
      return unless cmd_type
      if cmd_type == Boolean
        if cmd_search[/true/i]
          item[cmd]
        else
          item[cmd] == false
        end
      elsif allow_existence_boolean && (cmd_search[/true/i] || cmd_search[/false/i])
        if cmd_search == 'true'
          item[cmd]
        else
          item[cmd] == nil
        end
      elsif !item.key?(cmd)
        return false
      elsif val[1][:type] == :str
        item[cmd][/#{Regexp.escape(cmd_search)}/mi]
      elsif val[1][:type] == :quoted_str
        item[cmd][/\b#{Regexp.escape(cmd_search)}\b/]
      else
        item[cmd].to_s[/#{Regexp.escape(cmd_search)}/mi]
      end
    end

    def compare_check(item, node, val)
      fn = node[:nest_op].to_sym.to_proc
      args = val.map { |v| v[:type] == :number ? v[:value] : item[v[:value].to_sym] }
      return unless args.all?
      fn.call(*args.map(&:to_f))
    end

    def check(item, ast, fields, command_types)
      field_vals = fields.map { |x| item[x] }.compact
      ast_array = ast.kind_of?(Array) ? ast : [ast]
      ast_array.all? do |node|
        val = node[:value]
        case node[:nest_type]
        when :pipe
          val.any? { |v| check(item, v, fields, command_types) }
        when :minus
          !val.any? { |v| check(item, v, fields, command_types) }
        when :paren
          val.all? { |v| check(item, v, fields, command_types) }
        when :colon
          command_check(item, val, command_types)
        when :compare
          compare_check(item, node, val)
        when :quoted_str
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
