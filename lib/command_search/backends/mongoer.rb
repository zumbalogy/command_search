require('chronic')

module CommandSearch
  module Mongoer
    module_function

    def numeric_field?(field, command_types)
      type = command_types[field.to_sym]
      [Numeric, Integer].include?(type)
    end

    def build_str_regex(raw, type)
      str = Regexp.escape(raw)
      return /#{str}/i unless type == :quoted_str
      return '' if raw == ''
      return /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      Regexp.new(border_a + str + border_b)
    end

    def build_search(ast_node, fields, command_types)
      str = ast_node[:value] || ''
      fields = [fields] unless fields.is_a?(Array)
      regex = build_str_regex(str, ast_node[:type])

      forms = fields.map do |field|
        if numeric_field?(field, command_types)
          { field => str }
        else
          { field => regex }
        end
      end
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def build_time_command(key, val)
      time_str = val.tr('_.-', ' ')
      if time_str == time_str.to_i.to_s
        date_a = Time.new(time_str)
        date_b = Time.new(time_str.to_i + 1).yesterday
      else
        date = Chronic.parse(time_str, guess: nil) || Chronic.parse(val, guess: nil)
        return [{ CommandSeachDummyDate: true }, { CommandSeachDummyDate: false }] unless date
        date_a = date.begin
        date_b = date.end
      end
      [
        { key => { '$gte' => date_a } },
        { key => { '$lte' => date_b } }
      ]
    end

    def build_command(ast_node, command_types)
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      type = command_types[key.to_sym]

      raw_val = search_node[:value]
      search_type = search_node[:type]

      if search_type == Boolean
        val = [
          { key => { '$exists' => true } },
          { key => { '$ne' => !raw_val } }
        ]
        key = '$and'
      elsif search_type == :existence
        # These queries return true for empty arrays.
        if raw_val
          val = [
            { key => { '$exists' => true } },
            { key => { '$ne' => false } }
          ]
          key = '$and'
        else
          val = { '$exists' => false }
        end
      elsif type == String
        val = build_str_regex(raw_val, search_type)
      elsif [Numeric, Integer].include?(type)
        val = raw_val
      elsif [Date, Time, DateTime].include?(type)
        return build_time_command(key, raw_val)
      end
      { key => val }
    end

    def build_compare(ast_node, command_types)
      flip_ops = {
        '<' => '>',
        '>' => '<',
        '<=' => '>=',
        '>=' => '<='
      }
      mongo_op_map = {
        '<' => '$lt',
        '>' => '$gt',
        '<=' => '$lte',
        '>=' => '$gte'
      }

      keys = command_types.keys
      (first_node, last_node) = ast_node[:value]
      key = first_node[:value]
      val = last_node[:value]
      op = ast_node[:nest_op]

      if keys.include?(val.to_sym)
        (key, val) = [val, key]
        op = flip_ops[op]
      end

      mongo_op = mongo_op_map[op]
      type = command_types[key.to_sym]

      if command_types[val.to_sym]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
      elsif [Date, Time, DateTime].include?(type)
        # foo <  day | day.start
        # foo <= day | day.end
        # foo >  day | day.end
        # foo >= day | day.start
        date_start_map = {
          '<' => :start,
          '>' => :end,
          '<=' => :end,
          '>=' => :start
        }
        date_pick = date_start_map[op]
        time_str = val.tr('_.-', ' ')

        if time_str == time_str.to_i.to_s
          date = [Time.new(time_str), Time.new(time_str.to_i + 1).yesterday]
        else
          date = Chronic.parse(time_str, guess: nil) || Chronic.parse(val, guess: nil)
        end

        date = date || []

        if date_pick == :start
          val = date.first
        elsif date_pick == :end
          val = date.last
        end
      end
      { key => { mongo_op => val } }
    end

    def build_searches!(ast, fields, command_types)
      ast.map! do |x|
        type = x[:nest_type]
        if type == :colon
          build_command(x, command_types)
        elsif type == :compare
          build_compare(x, command_types)
        elsif [:paren, :pipe, :minus].include?(type)
          build_searches!(x[:value], fields, command_types)
          x
        else
          build_search(x, fields, command_types)
        end
      end
      ast.flatten!
    end

    def build_tree!(ast)
      mongo_types = { paren: '$and', pipe: '$or', minus: '$nor' }
      ast.each do |node|
        next node unless node[:nest_type]
        build_tree!(node[:value])
        key = mongo_types[node[:nest_type]]
        if key == '$nor' && node[:value].count > 1
          node[key] = [{ '$and' => node[:value] }]
        else
          node[key] = node[:value]
        end
        node['$or'].map! { |x| x['$or'] || x }.flatten! if node['$or']
        node['$nor'].map! { |x| x['$or'] || x }.flatten! if node['$nor']
        node.delete(:nest_type)
        node.delete(:nest_op)
        node.delete(:value)
        node.delete(:type)
      end
    end

    def build_query(ast, fields, command_types)
      out = ast
      build_searches!(out, fields, command_types)
      build_tree!(out)
      out = {} if out == []
      out = out.first if out.count == 1
      out = { '$and' => out } if out.count > 1
      out
    end
  end
end
