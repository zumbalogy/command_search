module CommandSearch
  module Memory
    module_function

    def command_check(item, val)
      cmd = val[0][:value].to_sym
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

    def compare_check(item, node, cmd_types)
      cmd = node[:value].first
      cmd_val = cmd[:value]
      cmd_type = cmd_types[cmd[:value].to_sym]
      item_val = item[cmd_val.to_sym] || item[cmd_val.to_s]
      search = node[:value].last
      val = search[:value]
      if val.is_a?(Time)
        item_val = item_val.to_time if item_val
      elsif search[:type] == :str && cmd_types[val.to_sym]
        val = item[val.to_sym] || item[val.to_s]
      end
      args = [item_val, val]
      return unless args.all?
      fn = node[:nest_op].to_sym.to_proc
      fn.call(*args.map(&:to_f))
    end

    def check(item, ast, fields, cmd_types)
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
          compare_check(item, node, cmd_types)
        when :minus
          !val.all? { |v| check(item, [v], fields, cmd_types) }
        when :pipe
          val.any? { |v| check(item, [v], fields, cmd_types) }
        when :paren
          val.all? { |v| check(item, [v], fields, cmd_types) }
        end
      end
    end
  end
end
