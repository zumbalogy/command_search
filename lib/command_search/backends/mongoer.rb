require('chronic')

module CommandSearch
  module Mongoer
    module_function

    def numeric_field?(field, command_types)
      # TODO: this could be cleaner/shared/generic or something
      raw_type = command_types[field.to_sym]
      if raw_type.is_a?(Array)
        type = (raw_type - [:allow_existence_boolean]).first
      else
        type = raw_type
      end
      [Numeric, Integer].include?(type)
    end

    def build_search(ast_node, fields, command_types)
      str = ast_node[:value] || ''
      fields = [fields] unless fields.is_a?(Array)
      if ast_node[:type] == :quoted_str
        regex = /\b#{Regexp.escape(str)}\b/
        if str[/(^\W)|(\W$)/]
          head_border = '(^|\s|[^:+\w])'
          tail_border = '($|\s|[^:+\w])'
          regex = Regexp.new(head_border + Regexp.escape(str) + tail_border)
        end
      else
        regex = /#{Regexp.escape(str)}/i
      end

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

    def is_bool_str?(str)
      str[/\Atrue\Z|\Afalse\Z/i]
    end

    def make_boolean(str)
      str[0] == 't'
    end

    def build_command(ast_node, command_types)
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      raw_type = command_types[key.to_sym]
      type = raw_type

      raw_val = search_node[:value]
      search_type = search_node[:type]

      if raw_type.is_a?(Array)
        is_bool = raw_type.include?(:allow_existence_boolean) && is_bool_str?(raw_val) && search_type != :quoted_str
        type = (raw_type - [:allow_existence_boolean]).first
      else
        is_bool = false
        type = raw_type
      end

      if type == Boolean
        bool = make_boolean(raw_val)
        val = [
          { key => { '$exists' => true } },
          { key => { '$ne' => !bool } }
        ]
        key = '$and'
      elsif is_bool
        # These queries return true for empty arrays.
        bool = make_boolean(raw_val)
        if bool
          val = [
            { key => { '$exists' => true } },
            { key => { '$ne' => false } }
          ]
          key = '$and'
        else
          val = { '$exists' => false }
        end
      elsif type == String
        if search_type == :quoted_str
          val = /\b#{Regexp.escape(raw_val)}\b/
          val = '' if raw_val == ''
          if raw_val[/(^\W)|(\W$)/]
            head_border = '(^|\s|[^:+\w])'
            tail_border = '($|\s|[^:+\w])'
            val = Regexp.new(head_border + Regexp.escape(raw_val) + tail_border)
          end
        else
          val = /#{Regexp.escape(raw_val)}/i
        end
      elsif [Numeric, Integer].include?(type)
        if raw_val == raw_val.to_i.to_s
          val = raw_val.to_i
        elsif raw_val.to_f != 0 || raw_val[/\A[\.0]*0\Z/]
          val = raw_val.to_f
        else
          val = raw_val
        end
      elsif [Date, Time, DateTime].include?(type)
        time_str = raw_val.tr('_.-', ' ')
        if time_str == time_str.to_i.to_s
          date_begin = Time.utc(time_str)
          date_end = Time.utc(time_str.to_i + 1).yesterday # TODO: make a test that fails if not UTC here.
        else
          date = Chronic.parse(time_str, guess: nil) || Chronic.parse(raw_val, guess: nil)
          date_begin = date.begin
          date_end = date.end
        end
        val = [
          { key => { '$gte' => date_begin } },
          { key => { '$lte' => date_end   } }
        ]
        key = '$and'
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
      raw_type = command_types[key.to_sym]

      if raw_type.is_a?(Array)
        type = (raw_type - [:allow_boolean]).first # TODO: this should be allow_existence_boolean and is a bug and should have a failing test
      else
        type = raw_type
      end

      if command_types[val.to_sym]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
      elsif [Numeric, Integer].include?(type)
        if val == val.to_i.to_s
          val = val.to_i
        else
          val = val.to_f
        end
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
          date = [Time.utc(time_str), Time.utc(time_str.to_i + 1).yesterday] # TODO: make a test that fails if not UTC here.
        else
          date = Chronic.parse(time_str, guess: nil) || Chronic.parse(val, guess: nil)
        end

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
