module CommandSearch
  module Memory
    module_function

    def command_check(item, val)
      cmd = val[0][:value]
      cmd_search = val[1][:value]
      item_val = item[cmd.to_sym] || item[cmd]
      val_type = val[1][:type]
      val_type = Boolean if val_type == :existence && cmd_search == true
      if val_type == Boolean
        !!item_val == cmd_search
      elsif val_type == :existence
        item_val == nil
      elsif !item_val
        return false
      elsif val_type == Time
        item_time = item_val.to_time
        cmd_search.first <= item_time && item_time < cmd_search.last
      elsif cmd_search.is_a?(Regexp)
        item_val[cmd_search]
      elsif cmd_search == ''
        item_val == cmd_search
      else
        item_val.to_s[/#{Regexp.escape(cmd_search)}/i]
      end
    end

    def compare_check(item, node)
      cmd_val = node[:value].first[:value]
      item_val = item[cmd_val.to_sym] || item[cmd_val.to_s]
      return unless item_val
      val = node[:value].last[:value]
      if val.is_a?(Time)
        item_val = item_val.to_time
      elsif node[:compare_across_fields]
        val = item[val.to_sym] || item[val.to_s]
      end
      return unless val
      fn = node[:nest_op].to_sym.to_proc
      fn.call(item_val.to_f, val.to_f)
    end

    def check(item, ast, fields)
      ast.all? do |node|
        val = node[:value]
        case node[:nest_type]
        when nil
          fields.any? do |x|
            item_val = item[x.to_sym] || item[x.to_s]
            item_val.to_s[val] if item_val
          end
        when :colon
          command_check(item, val)
        when :compare
          compare_check(item, node)
        when :minus
          !val.all? { |v| check(item, [v], fields) }
        when :pipe
          val.any? { |v| check(item, [v], fields) }
        when :paren
          val.all? { |v| check(item, [v], fields) }
        end
      end
    end
  end
end
