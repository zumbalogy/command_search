require('chronic')

module CommandSearch
  module Memory

    def self.command_check(item, val, command_types)
      cmd = val[0][:value].to_sym
      cmd_search = val[1][:value]
      raw_cmd_type = [command_types[cmd]].flatten
      allow_existence_boolean = raw_cmd_type.include?(:allow_existence_boolean)
      cmd_type = (raw_cmd_type - [:allow_existence_boolean]).first
      if cmd_type == Boolean
        if cmd_search[/true/i]
          item[cmd]
        else
          item[cmd] == false
        end
      elsif allow_existence_boolean && (cmd_search[/true/i] || cmd_search[/false/i])
        if cmd_search[/true/i]
          item[cmd]
        else
          item[cmd] == nil
        end
      elsif !item.key?(cmd)
        return false
      elsif val[1][:type] == :quoted_str
        regex = /\b#{Regexp.escape(cmd_search)}\b/
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

    def self.compare_check(item, node, command_types)
      children = node[:value]
      cmd = children.find { |c| command_types[c[:value].to_sym] }
      raw_cmd_type = [command_types[cmd[:value].to_sym]].flatten
      cmd_type = (raw_cmd_type - [:allow_existence_boolean]).first

      args = children.map do |child|
        child_val = child[:value]
        item_val = item[child_val.to_s] || item[child_val.to_sym]
        item_val ||= child_val unless child == cmd
        return unless item_val
        if cmd_type == Time
          date_start_map = {
            '<' => :start,
            '>' => :end,
            '<=' => :end,
            '>=' => :start
          }
          date_pick = date_start_map[node[:nest_op]]
          time_str = item_val.gsub(/[\._-]/, ' ')
          date = Chronic.parse(time_str, { guess: nil })
          if date_pick == :start
            date.first
          else
            date.last
          end
        else
          item_val
        end
      end
      return unless args.all?
      fn = node[:nest_op].to_sym.to_proc
      fn.call(*args.map(&:to_f))
    end

    def self.check(item, ast, fields, command_types)
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
          val.none? { |v| check(item, v, fields, command_types) }
        when :paren
          val.all? { |v| check(item, v, fields, command_types) }
        end
      end
    end

    def self.build_query(ast, fields, command_types = {})
      proc { |x| check(x, ast, fields, command_types) }
    end
  end
end
