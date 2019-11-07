require('chronic')

module CommandSearch
  module Normalizer
    module_function

    def cast_bool!(type, node)
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

    def cast_time!(node)
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

    def cast_regex!(node)
      type = node[:type]
      raw = node[:value]
      return unless raw.is_a?(String)
      return if node[:value] == ''
      str = Regexp.escape(raw)
      return node[:value] = /#{str}/i unless type == :quoted_str
      return node[:value] = /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      node[:value] = Regexp.new(border_a + str + border_b)
    end

    def clean_comparison!(node, cmd_fields)
      val = node[:value]
      return unless cmd_fields[val[1][:value].to_sym]
      if cmd_fields[val[0][:value].to_sym]
        node[:compare_across_fields] = true
        return
      end
      flip_ops = { '<' => '>', '>' => '<', '<=' => '>=', '>=' => '<=' }
      node[:nest_op] = flip_ops[node[:nest_op]]
      node[:value].reverse!
    end

    def dealias_key(key, cmd_fields)
      key = cmd_fields[key.to_sym] while cmd_fields[key.to_sym].is_a?(Symbol)
      key.to_s
    end

    def dealias!(ast, fields, cmd_fields)
      ast.map! do |node|
        nest = node[:nest_type]
        next node unless nest
        unless nest == :colon || nest == :compare
          dealias!(node[:value], fields, cmd_fields)
          next node
        end
        clean_comparison!(node, cmd_fields) if nest == :compare
        (key_node, search_node) = node[:value]
        new_key = dealias_key(key_node[:value], cmd_fields)
        type = cmd_fields[new_key.to_sym]
        node[:value][0][:value] = new_key
        if type
          cast_bool!(type, search_node)
          type = (type - [:allow_existence_boolean]).first if type.is_a?(Array)
          cast_time!(node) if [Time, Date, DateTime].include?(type)
          cast_regex!(search_node) if type == String
          next node
        end
        str_values = "#{new_key}#{node[:nest_op]}#{search_node[:value]}"
        node = { type: :str, value: str_values }
        cast_regex!(node)
        node
      end
    end

    def fold_in_general_thingies!(ast, fields, cmd_fields)
      ast.map! do |node|
        if node[:type] == :nest
          type = node[:nest_type]
          if type == :minus || type == :paren || type == :pipe
            fold_in_general_thingies!(node[:value], fields, cmd_fields)
          elsif type == :colon
            field = node[:value][0][:value]
            foo_type = cmd_fields[field.to_sym] || cmd_fields[field.to_s]
            if foo_type == Numeric && node[:value][1][:type] == :number
              node[:value][1][:value] = node[:value][1][:value].to_f
            end
          end
          next node
        end
        fields = [:__CommandSearch_dummy_key__] if fields.empty?
        original_val = node[:value]
        cast_regex!(node)
        new_val = fields.map do |field|
          foo_type = cmd_fields[field.to_sym] || cmd_fields[field.to_s]
          is_numeric = foo_type == Numeric
          {
            type: :nest,
            nest_type: :colon,
            value: [
              {
                value: field
              },
              {
                value: is_numeric ? original_val.to_f : node[:value],
                type: node[:type]
              }
            ]
          }
        end
        next new_val.first if new_val.count < 2
        { type: :nest, nest_type: :pipe, value: new_val }
      end
      ast.compact!
    end

    def normalize!(ast, fields, cmd_fields)
      dealias!(ast, fields, cmd_fields)
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
      fold_in_general_thingies!(ast, fields, clean)
    end
  end
end
