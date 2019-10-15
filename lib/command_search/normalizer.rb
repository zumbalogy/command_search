require('chronic')

module CommandSearch
  module Normalizer
    module_function

    def cast_bool(type, node)
      if type == Boolean
        node[:type] = Boolean
        node[:value] = !!node[:value][0][/t/i]
        return
      end
      return unless type.is_a?(Array) && type.include?(:allow_existence_boolean)
      return unless node[:type] == :str && node[:value][/\Atrue\Z|\Afalse\Z/i]
      node[:type] = :existence
      node[:value] = !!node[:value][0][/t/i]
    end

    def cast_time(node)
      search_node = node[:value][1]
      search_node[:type] = Time
      str = search_node[:value]
      if str == str.to_i.to_s
        search_node[:value] = [Time.new(str), Time.new(str.to_i + 1)]
      else
        time_str = str.tr('._-', ' ')
        times = Chronic.parse(time_str, { guess: nil })
        times ||= Chronic.parse(str, { guess: nil })
        if times
          search_node[:value] = [times.first, times.last]
        else
          search_node[:value] = nil
          return
        end
      end
      return unless node[:nest_type] == :compare
      op = node[:nest_op]
      if op == '<' || op == '>='
        search_node[:value] = search_node[:value].first
      else
        search_node[:value] = search_node[:value].last
        search_node[:value] -= 1
      end
    end

    def cast_regex(node)
      type = node[:type]
      return unless type == :str || type == :quoted_str || type == :number
      raw = node[:value]
      str = Regexp.escape(raw)
      return node[:value] = /#{str}/i unless type == :quoted_str
      return node[:value] = '' if raw == ''
      return node[:value] = /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      node[:value] = Regexp.new(border_a + str + border_b)
    end

    def flip_operator!(node, cmd_fields)
      val = node[:value]
      return if cmd_fields[val[0][:value].to_sym]
      return unless cmd_fields[val[1][:value].to_sym]
      flip_ops = { '<' => '>', '>' => '<', '<=' => '>=', '>=' => '<=' }
      node[:nest_op] = flip_ops[node[:nest_op]]
      node[:value].reverse!
    end

    def dealias_key(key, cmd_fields)
      key = cmd_fields[key.to_sym] while cmd_fields[key.to_sym].is_a?(Symbol)
      key.to_s
    end

    def dealias!(ast, cmd_fields)
      ast.map! do |node|
        nest = node[:nest_type]
        unless nest
          node[:number_value] = node[:value] if node[:type] == :number
          cast_regex(node)
          next node
        end
        unless nest == :colon || nest == :compare
          dealias!(node[:value], cmd_fields)
          next node
        end
        flip_operator!(node, cmd_fields) if nest == :compare
        (key_node, search_node) = node[:value]
        new_key = dealias_key(key_node[:value], cmd_fields)
        type = cmd_fields[new_key.to_sym]
        node[:value][0][:value] = new_key
        if type
          cast_bool(type, search_node)
          type = (type - [:allow_existence_boolean]).first if type.is_a?(Array)
          cast_time(node) if [Time, Date, DateTime].include?(type)
          cast_regex(search_node) if type == String
          next node
        end
        str_values = "#{new_key}#{node[:nest_op]}#{search_node[:value]}"
        node = { type: :str, value: str_values }
        cast_regex(node)
        node
      end
    end

    def normalize!(ast, cmd_fields)
      dealias!(ast, cmd_fields)
      clean = {}
      cmd_fields.each do |k, v|
        next if v.is_a?(Symbol)
        if v.is_a?(Array)
          clean[k] = (v - [:allow_existence_boolean]).first
          next
        end
        v = Numeric if v == Integer
        v = Time if v == Date
        v = Time if v == DateTime
        next clean[k] = v
      end
      clean
    end
  end
end
