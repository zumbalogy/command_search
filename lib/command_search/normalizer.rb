require('chronic')

module CommandSearch
  module Normalizer
    module_function

    def cast_bool!(field, node)
      type = field.is_a?(Hash) ? field[:type] : field
      if type == Boolean
        return if field.is_a?(Hash) && field[:general_search] && !node[:value][/\Atrue\Z|\Afalse\Z/i]
        node[:type] = Boolean
        node[:value] = !!node[:value][0][/t/i]
        return
      end
      return unless field.is_a?(Hash) && field[:allow_existence_boolean]
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
      return unless node[:type] == :compare
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
      return node[:value] = /#{str}/i unless type == :quote
      return node[:value] = /\b#{str}\b/ unless raw[/(\A\W)|(\W\Z)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      node[:value] = Regexp.new(border_a + str + border_b)
    end

    def cast_numeric!(node)
      return unless node[:type] == :number
      node[:value] = node[:value].to_f
    end

    def clean_comparison!(node, fields)
      val = node[:value]
      return unless fields[val[1][:value].to_sym]
      if fields[val[0][:value].to_sym]
        node[:compare_across_fields] = true
        return
      end
      flip_ops = { '<' => '>', '>' => '<', '<=' => '>=', '>=' => '<=' }
      node[:nest_op] = flip_ops[node[:nest_op]]
      node[:value].reverse!
    end

    def dealias_key(key, fields)
      key = fields[key.to_sym] while fields[key.to_sym].is_a?(Symbol)
      key
    end

    def split_general_fields(node, fields)
      general_fields = fields.select { |k, v| v.is_a?(Hash) && v[:general_search] }.keys
      general_fields = ['__CommandSearch_dummy_key__'] if general_fields.empty?
      new_val = general_fields.map! do |field|
        {
          type: :colon,
          value: [
            { value: field.to_s },
            { value: node[:value], type: node[:type] }
          ]
        }
      end
      return new_val.first if new_val.count < 2
      { type: :or, value: new_val }
    end

    def type_cast!(node, fields, cast_all)
      (key_node, search_node) = node[:value]
      key = key_node[:value]
      field = fields[key.to_sym] || fields[key.to_s]
      return unless field
      type = field.is_a?(Class) ? field : field[:type]
      type = Numeric if type == Integer
      key_node[:field_type] = type
      search_node[:original_value] = search_node[:value]
      cast_bool!(field, search_node)
      return cast_time!(node) if [Time, Date, DateTime].include?(type)
      return cast_numeric!(search_node) if Numeric == type
      if cast_all
        cast_regex!(search_node)
      else
        search_node[:type] = :str if search_node[:type] == :number
      end
    end

    def normalize!(ast, fields, cast_all = true)
      ast.map! do |node|
        if node[:type] == :and || node[:type] == :or || node[:type] == :not
          normalize!(node[:value], fields)
          next node
        end
        if node[:type] == :colon || node[:type] == :compare
          clean_comparison!(node, fields) if node[:type] == :compare
          key = dealias_key(node[:value][0][:value], fields)
          node[:value][0][:value] = key.to_s
          unless fields[key.to_sym] || fields[key.to_s]
            str_values = "#{key}#{node[:nest_op]}#{node[:value][1][:value]}"
            node = { type: :str, value: str_values }
          end
        end
        if node[:type] == :str || node[:type] == :quote || node[:type] == :number
          node = split_general_fields(node, fields)
        end
        if node[:type] == :or
          node[:value].each { |x| type_cast!(x, fields, cast_all) }
        else
          type_cast!(node, fields, cast_all)
        end
        node
      end
    end
  end
end
