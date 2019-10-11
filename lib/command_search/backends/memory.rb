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
        item_time ||= item[cmd].to_time
        cmd_search.first <= item_time && item_time < cmd_search.last
      elsif val[1][:type] == :quoted_str
        regex = /\b#{Regexp.escape(cmd_search)}\b/
        regex = /\A\Z/ if cmd_search == ''
        if cmd_search[/(^\W)|(\W$)/]
          head_border = '(?<=^|[^:+\w])'
          tail_border = '(?=$|[^:+\w])'
          regex = Regexp.new(head_border + Regexp.escape(cmd_search) + tail_border)
        end
        item[cmd][regex]
      else
        item[cmd].to_s[/#{Regexp.escape(cmd_search)}/i]
      end
    end

    def compare_check(item, node, command_types)
      cmd = node[:value].first
      cmd_val = cmd[:value]
      cmd_type = command_types[cmd[:value].to_sym]
      search = node[:value].last
      item_val = item[cmd_val.to_sym] || item[cmd_val.to_s]
      if search[:value].is_a?(Time)
          item_val = item_val.to_time if item_val.class == DateTime || item_val.class == Date
        search_val = search[:value]
      else
        search_val = item[search[:value].to_sym] || item[search[:value].to_s] || search[:value]
      end
      args = [item_val, search_val]
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
          if node[:type] == :quoted_str
            regex = /\b#{Regexp.escape(val)}\b/
            if val[/(^\W)|(\W$)/]
              head_border = '(?<=^|[^:+\w])'
              tail_border = '(?=$|[^:+\w])'
              regex = Regexp.new(head_border + Regexp.escape(val) + tail_border)
            end
            field_vals.any? { |x| x.to_s[regex] }
          else
            field_vals.any? { |x| x.to_s[/#{Regexp.escape(val)}/i] }
          end
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
