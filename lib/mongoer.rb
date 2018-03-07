require('chronic')

class Mongoer
  class << self

    def build_search(str, fields)
      fields = [fields] unless fields.is_a?(Array)
      forms = fields.map { |f| { f => /#{Regexp.escape(str)}/mi } }
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def is_bool_str?(str)
      return true if str[/^true$|^false$/i]
      false
    end

    def make_boolean(str)
      return true if str[/^true$/i]
      false
    end

    def build_command(ast_node, command_types)
      # aliasing will be probably done before ast gets to mongoer.rb
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      raw_type = command_types[key.to_sym]

      raw_val = search_node[:value]
      search_type = search_node[:type]

      if raw_type.is_a?(Array)
        is_bool = raw_type.include?(:allow_existence_boolean) &&
                  is_bool_str?(raw_val) &&
                  search_type != :quoted_str
        type = (raw_type - [:allow_existence_boolean]).first
      else
        is_bool = false
        type = raw_type
      end

      if defined?(Boolean) && type = Boolean
        val = make_boolean(raw_val)
      elsif is_bool
        # This returns true for empty arrays, when it probably should not.
        # Alternativly, something like tags>5 could return things that have more
        # than 5 tags in the array.
        # https://stackoverflow.com/questions/22367335/mongodb-check-if-value-exists-for-a-field-in-a-document
        val = { '$exists' => make_boolean(raw_val) }
      elsif type == String
        if search_type == :quoted_string
          val = /#{Regexp.escape(raw_val)}/
        else
          val = /#{Regexp.escape(raw_val)}/mi
        end
      elsif type == Numeric # should maybe accept float and int seperatly too
        if raw_val == raw_val.to_i.to_s
          val = raw_val.to_i
        else
          val = raw_val.to_f
        end
      elsif type == Time # Should handle date too maybe?
        date = Chronic.parse(raw_val, { guess: nil })
        val = [{ key => { '$gte' => date.begin } },
               { key => { '$lte' => date.end   } }]
        key = '$and'
      end

      # regex (case insensitive probably best default, and let
      # proper regex and alias support allow developers to have
      # case sensitive if they want maybe.)

      { key => val }
    end

    def build_compare(ast_node, command_types)
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      raw_val = search_node[:value]
      raw_op = ast_node[:nest_op]
      raw_type = command_types[key.to_sym]

      if raw_type.is_a?(Array)
        type = (raw_type - [:allow_boolean]).first
      else
        type = raw_type
      end

      op_map = {
        '<' => '$lt',
        '>' => '$gt',
        '<=' => '$lte',
        '>=' => '$gte'
      }
      op = op_map[raw_op]
      if type == Numeric
        if raw_val == raw_val.to_i.to_s
          val = raw_val.to_i
        else
          val = raw_val.to_f
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
        date_pick = date_start_map[raw_op]
        date = Chronic.parse(raw_val, { guess: nil })
        if date_pick == :start
          val = date.first
        elsif date_pick == :end
          val = date.last
        end
      end
      { key => { op => val } }
    end

    def build_searches(ast, fields, command_types)
      ast.flat_map do |x|
        case x[:nest_type]
        when nil
          x = build_search(x[:value], fields)
        when :colon
          x = build_command(x, command_types)
        when :compare
          x = build_compare(x, command_types)
          x
        else
          # [:paren, :pipe, :minus]
          x[:value] = build_searches(x[:value], fields, command_types)
          x
        end
      end
    end

    def build_tree(ast)
      ast.flat_map do |x|
        next x unless x[:nest_type]
        mongo_types = { paren: '$and', pipe: '$or', minus: '$not' }
        key = mongo_types[x[:nest_type]]
        { key => build_tree(x[:value]) }
      end
    end

    def collapse_ors(ast)
      ast.flat_map do |x|
        ['$and', '$or', '$not'].map do |key|
          next unless x[key]
          x[key] = collapse_ors(x[key])
        end
        next x unless x['$or']
        val = x['$or'].flat_map { |kid| kid['$or'] || kid }
        { '$or' => val }
      end
    end

    def build_query(ast, fields, command_types = {})
      # Numbers are searched as strings unless part of a compare/command
      out = ast
      out = build_searches(out, fields, command_types)
      out = build_tree(out)
      out = collapse_ors(out)
      out = out.first if out.count == 1
      out = { '$and' => out } if out.count > 1
      out
    end
  end
end
