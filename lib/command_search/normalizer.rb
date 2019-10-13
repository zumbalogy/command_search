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

    def cast_time(type, node)
      return unless [Time, Date, DateTime].include?(type)
      search_node = node[:value][1]
      search_node[:type] = Time
      str = search_node[:value]

      if str == str.to_i.to_s
        search_node[:value] = [Time.new(str), Time.new(str.to_i + 1)]
      else
        time_str = str.tr('._-', ' ')
        input_times = Chronic.parse(time_str, { guess: nil }) || Chronic.parse(str, { guess: nil })
        if input_times
          search_node[:value] = [input_times.first, input_times.last]
        else
          search_node[:value] = nil
          return
        end
      end

      if node[:nest_type] == :compare
        date_start_map = {
          '<' => :start,
          '>' => :end,
          '<=' => :end,
          '>=' => :start
        }
        op = node[:nest_op]
        date_pick = date_start_map[op]
        if date_pick == :start
          search_node[:value] = search_node[:value].first
        else
          search_node[:value] = search_node[:value].last
          search_node[:value] -= 1
        end
      end
    end

    def cast_regex(type, node)
      return unless type == String # is this safe from :allow_existene bool?
      # TODO: this is ugly, and also only is for commands.
      return unless node[:type] == :str || node[:type] == :quoted_str || node[:type] == :number
      raw = node[:value]
      str = Regexp.escape(raw)
      return node[:value] = /#{str}/i unless node[:type] == :quoted_str
      return node[:value] = '' if raw == ''
      return node[:value] = /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      node[:value] = Regexp.new(border_a + str + border_b)
    end

    def cast_type(type, node)
      search_node = node[:value][1]
      cast_bool(type, search_node)
      clean_type = type
      clean_type = (type - [:allow_existence_boolean]).first if type.is_a?(Array)
      cast_time(clean_type, node)
      cast_regex(clean_type, search_node)
    end

    def flip_operator!(node, aliases)
      # TODO: make this take precidence for first item. and write specs for that
      return unless node[:nest_type] == :compare
      if (!aliases[node[:value][0][:value].to_sym] && aliases[node[:value][1][:value].to_sym])
        flip_ops = {
          '<' => '>',
          '>' => '<',
          '<=' => '>=',
          '>=' => '<='
        }
        node[:nest_op] = flip_ops[node[:nest_op]]
        node[:value].reverse!
      end
    end

    def dealias_key(key, aliases)
      key = aliases[key.to_sym] while aliases[key.to_sym].is_a?(Symbol)
      key.to_s
    end

    def dealias_values(node, aliases)
      (key_node, search_node) = node[:value]
      new_key = dealias_key(key_node[:value], aliases)
      type = aliases[new_key.to_sym]
      cast_type(type, node) if type
      key_node[:value] = new_key
      [key_node, search_node]
    end

    def unnest_unaliased(node, aliases)
      type = node[:nest_type]
      if type == :colon
        val = node[:value][0][:value].to_sym
        return node if aliases[val]
      elsif type == :compare
        return node if node[:value].any? { |child| aliases[child[:value].to_sym] }
      end
      values = node[:value].map { |x| x[:value] }
      str_values = values.join(node[:nest_op])
      { type: :str, value: str_values }
    end

    def cast_all_types!(ast, aliases)
      ast.map! do |node|
        # new_key = dealias_key(key_node[:value], aliases)
        # type = aliases[new_key.to_sym]
        # cast_type(type, node) if type

        if node[:type] == :str
          cast_regex(String, node)
        end
        if node[:type] == :quoted_str
          cast_regex(String, node)
        end
        if node[:type] == :number
          node[:number_value] = node[:value]
          cast_regex(String, node)
        end

        # if node[:nest_type] == :colon || node[:nest_type] == :compare
        #
        # end

        cast_all_types!(node[:value], aliases) if node[:nest_type] == :pipe
        cast_all_types!(node[:value], aliases) if node[:nest_type] == :paren
        cast_all_types!(node[:value], aliases) if node[:nest_type] == :minus
        node
      end
    end

    def dealias!(ast, aliases)
      ast.map! do |node|
        next node unless node[:nest_type]
        dealias!(node[:value], aliases)
        next node unless [:colon, :compare].include?(node[:nest_type])
        flip_operator!(node, aliases)
        node[:value] = dealias_values(node, aliases)
        node
      end
    end

    def clean_command_fields(aliases)
      out = {}
      aliases.each do |k, v|
        next if v.is_a?(Symbol)
        if v.is_a?(Array)
          out[k] = (v - [:allow_existence_boolean]).first
          next
        end
        v = Numeric if v == Integer
        v = Time if v == Date
        v = Time if v == DateTime
        next out[k] = v
      end
      out
    end

    def decompose_unaliasable!(ast, aliases)
      ast.map! do |x|
        next x unless x[:nest_type]
        decompose_unaliasable!(x[:value], aliases)
        next x unless [:colon, :compare].include?(x[:nest_type])
        unnest_unaliased(x, aliases)
      end
    end


    def normalize!(ast, command_fields)
      dealias!(ast, command_fields)
      decompose_unaliasable!(ast, command_fields)
      cast_all_types!(ast, command_fields)

      cleaned_cmd_fields = clean_command_fields(command_fields)
    end
  end
end
