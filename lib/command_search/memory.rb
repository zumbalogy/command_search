module CommandSearch
  module Memory
    module_function

    def command_check(item, val, command_types)
      cmd = val[0][:value].to_sym
      cmd_type = command_types[cmd]
      cmd_search = val[1][:value]
      val_type = val[1][:type]
      val_type = Boolean if val_type == :existence && cmd_search == true
      if val_type == Boolean
        !!item[cmd] == cmd_search
      elsif val_type == :existence
        item[cmd] == nil
      elsif !item.key?(cmd)
        return false
      elsif val_type == Time
        item_time = item[cmd].to_time
        cmd_search.first <= item_time && item_time < cmd_search.last
      elsif cmd_search.is_a?(Regexp)
        item[cmd][cmd_search]
      elsif cmd_search == ''
        item[cmd] == cmd_search
      else
        item[cmd].to_s[/#{Regexp.escape(cmd_search)}/i]
      end
    end

    def compare_check(item, node, command_types)
      cmd = node[:value].first
      cmd_val = cmd[:value]
      cmd_type = command_types[cmd[:value].to_sym]
      item_val = item[cmd_val.to_sym] || item[cmd_val.to_s]
      search = node[:value].last
      val = search[:value]
      if val.is_a?(Time)
        item_val = item_val.to_time if item_val
      elsif search[:type] == :str && command_types[val.to_sym]
        val = item[val.to_sym] || item[val.to_s]
      end
      args = [item_val, val]
      return unless args.all?
      fn = node[:nest_op].to_sym.to_proc
      fn.call(*args.map(&:to_f))
    end

    def check(item, ast, fields, command_types)
      field_vals = fields.map { |x| item[x] || item[x.to_s] || item[x.to_sym] }.compact
      ast_array = ast.is_a?(Array) ? ast : [ast]
      ast_array.all? do |node|
        val = node[:value]
        case node[:nest_type]
        when nil
          field_vals.any? { |x| x.to_s[val] }
        when :colon
          command_check(item, val, command_types)
        when :compare
          compare_check(item, node, command_types)
        when :pipe
          val.any? { |v| check(item, v, fields, command_types) }
        when :minus
          !val.all? { |v| check(item, v, fields, command_types) }
        when :paren
          val.all? { |v| check(item, v, fields, command_types) }
        end
      end
    end

    def build_query(ast, fields, command_types = {})
      proc { |x| check(x, ast, fields, command_types) }
    end
  end
end
