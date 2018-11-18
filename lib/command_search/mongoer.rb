require('chronic')

module CommandSearch
  module Mongoer

    def self.build_search(ast_node, fields)
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
        forms = fields.map { |f| { f => { '$not' => regex } } }
      else
        forms = fields.map { |f| { f => regex } }
      end
      return forms if forms.count < 2
      if ast_node[:negate]
        { '$and' => forms }
      else
        { '$or' => forms }
      end
    end

    def self.is_bool_str?(str)
      return true if str[/\Atrue\Z|\Afalse\Z/i]
      false
    end

    def self.make_boolean(str)
      return true if str[/\Atrue\Z/i]
      false
    end

    def self.build_command(ast_node, command_types)
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
      elsif type == Time
        time_str = raw_val.tr('_.-', ' ')
        date = Chronic.parse(time_str, guess: nil)
        if field_node[:negate]
          val = [
            { key => { '$gt' => date.end   } },
            { key => { '$lt' => date.begin } }
          ]
          key = '$or'
        else
          val = [
            { key => { '$gte' => date.begin } },
            { key => { '$lte' => date.end   } }
          ]
          key = '$and'
        end
      end

      if field_node[:negate] && (type == Numeric || type == String)
        { key => { '$not' => val } }
      else
        { key => val }
      end
    end

    def self.build_compare(ast_node, command_types)
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
      elsif type == Numeric
        if val == val.to_i.to_s
          val = val.to_i
        else
          val = val.to_f
        end
      elsif type == Time
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
        date = Chronic.parse(time_str, guess: nil)
        if date_pick == :start
          val = date.first
        elsif date_pick == :end
          val = date.last
        end
      end
      { key => { mongo_op => val } }
    end

    def self.build_searches!(ast, fields, command_types)
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
          build_search(x, fields)
        end
      end
      ast.flatten!
    end

    def self.build_tree!(ast)
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

    def self.collapse_ors!(ast)
      ast.each do |x|
        next unless x['$or']
        x['$or'].map! { |kid| kid['$or'] || kid }.flatten!
      end
    end

    def self.decompose_nots(ast, not_depth = 0)
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

    def self.build_query(ast, fields, command_types = {})
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
