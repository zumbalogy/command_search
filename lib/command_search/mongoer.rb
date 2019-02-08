require('chronic')

module CommandSearch
  module Mongoer
    module_function

    def build_search(ast_node, fields, command_types)
      str = ast_node[:value] || ''
      fields = [fields] unless fields.is_a?(Array)
      if ast_node[:type] == :quoted_str
        regex = /\b#{Regexp.escape(str)}\b/
        if str[/(^\W)|(\W$)/]
          head_border = '(?<=^|[^:+\w])'
          tail_border = '(?=$|[^:+\w])'
          regex = Regexp.new(head_border + Regexp.escape(str) + tail_border)
        end
      else
        regex = /#{Regexp.escape(str)}/i
      end
      if ast_node[:negate]
        forms = fields.map do |field|
          if [Numeric, Integer].include?(command_types[field.to_sym])
            { field => { '$ne' => str } }
          else
            { field => { '$not' => regex } }
          end
        end
      else
        forms = fields.map { |f| { f => regex } }
        forms = fields.map do |field|
          if [Numeric, Integer].include?(command_types[field.to_sym])
            { field => str }
          else
            { field => regex }
          end
        end
      end
      return forms if forms.count < 2
      if ast_node[:negate]
        { '$and' => forms }
      else
        { '$or' => forms }
      end
    end

    def is_bool_str?(str)
      str[/\Atrue\Z|\Afalse\Z/i]
    end

    def make_boolean(str)
      str[/\Atrue\Z/i]
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
        bool = !bool if field_node[:negate]
        val = [
          { key => { '$exists' => true } },
          { key => { '$ne' => !bool } }
        ]
        key = '$and'
      elsif is_bool
        # This returns true for empty arrays, when it probably should not.
        # Alternativly, something like tags>5 could return things that have more
        # than 5 tags in the array.
        # https://stackoverflow.com/questions/22367335/mongodb-check-if-value-exists-for-a-field-in-a-document
        # val = { '$exists' => make_boolean(raw_val) }
        bool = make_boolean(raw_val)
        bool = !bool if field_node[:negate]
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
            head_border = '(?<=^|[^:+\w])'
            tail_border = '(?=$|[^:+\w])'
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
          date_begin = Time.new(time_str)
          date_end = Time.new(time_str.to_i + 1).yesterday
        else
          date = Chronic.parse(time_str, guess: nil) || Chronic.parse(raw_val, guess: nil)
          date_begin = date.begin
          date_end = date.end
        end
        if field_node[:negate]
          val = [
            { key => { '$gt' => date_end   } },
            { key => { '$lt' => date_begin } }
          ]
          key = '$or'
        else
          val = [
            { key => { '$gte' => date_begin } },
            { key => { '$lte' => date_end   } }
          ]
          key = '$and'
        end
      end
      if field_node[:negate] && [Numeric, Integer].include?(type)
        { key => { '$ne' => val } }
      elsif field_node[:negate] && type == String
        { key => { '$not' => val } }
      else
        { key => val }
      end
    end

    def build_compare(ast_node, command_types)
      flip_ops = {
        '<' => '>',
        '>' => '<',
        '<=' => '>=',
        '>=' => '<='
      }
      reverse_ops = {
        '<' => '>=',
        '<=' => '>',
        '>' => '<=',
        '>=' => '<'
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
      op = reverse_ops[op] if first_node[:negate]

      if keys.include?(val.to_sym)
        (key, val) = [val, key]
        op = flip_ops[op]
      end

      mongo_op = mongo_op_map[op]
      raw_type = command_types[key.to_sym]

      if raw_type.is_a?(Array)
        type = (raw_type - [:allow_boolean]).first
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
          date = [Time.new(time_str), Time.new(time_str.to_i + 1).yesterday]
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
      mongo_types = { paren: '$and', pipe: '$or', minus: '$not' }
      ast.each do |x|
        next x unless x[:nest_type]
        build_tree!(x[:value])
        key = mongo_types[x[:nest_type]]
        x[key] = x[:value]
        x.delete(:nest_type)
        x.delete(:nest_op)
        x.delete(:value)
        x.delete(:type)
      end
    end

    def collapse_ors!(ast)
      ast.each do |x|
        next unless x['$or']
        x['$or'].map! { |kid| kid['$or'] || kid }.flatten!
      end
    end

    def decompose_nots(ast, not_depth = 0)
      ast.flat_map do |x|
        if x[:nest_type] == :minus
          decompose_nots(x[:value], not_depth + 1)
        elsif x[:nest_type]
          x[:value] = decompose_nots(x[:value], not_depth)
          x
        else
          x[:negate] = not_depth.odd?
          x
        end
      end
    end

    def build_query(ast, fields, command_types = {})
      out = ast
      out = decompose_nots(out)
      build_searches!(out, fields, command_types)
      build_tree!(out)
      collapse_ors!(out)
      out = {} if out == []
      out = out.first if out.count == 1
      out = { '$and' => out } if out.count > 1
      out
    end
  end
end
