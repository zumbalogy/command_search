module CommandSearch
  module Mongoer
    module_function

    def build_search(node, fields, cmd_fields)
      val = node[:value]
      forms = fields.map do |field|
        type = cmd_fields[field.to_sym]
        if type == Numeric
          { field => node[:number_value] }
        else
          { field => val }
        end
      end
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def build_command(node)
      (field_node, search_node) = node[:value]
      key = field_node[:value]
      val = search_node[:value]
      search_type = search_node[:type]
      search_type = Boolean if search_type == :existence && val == true
      if search_type == Boolean
        # These queries can return true for empty arrays.
        val = [
          { key => { '$exists' => true } },
          { key => { '$ne' => !val } }
        ]
        key = '$and'
      elsif search_type == :existence
        val = { '$exists' => false }
      elsif search_type == Time
        return [{ CommandSearchNilTime: true }, { CommandSearchNilTime: false }] unless val
        return [
          { key => { '$gte' => val[0] } },
          { key => { '$lt' => val[1] } }
        ]
      end
      { key => val }
    end

    def build_compare(node, cmd_fields)
      op_map = { '<' => '$lt', '>' => '$gt', '<=' => '$lte', '>=' => '$gte' }
      op = op_map[node[:nest_op]]
      key = node[:value][0][:value]
      val = node[:value][1][:value]
      if val.class == String && cmd_fields[val.to_sym]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
      end
      { key => { op => val } }
    end

    def build_searches!(ast, fields, cmd_fields)
      mongo_types = { paren: '$and', pipe: '$or', minus: '$nor' }
      ast.map! do |node|
        type = node[:nest_type]
        if type == :colon
          build_command(node)
        elsif type == :compare
          build_compare(node, cmd_fields)
        elsif key = mongo_types[type]
          build_searches!(node[:value], fields, cmd_fields)
          val = node[:value]
          if key == '$nor' && val.count > 1
            next { key => [{ '$and' => val }] }
          end
          val.map! { |x| x['$or'] || x }.flatten! unless key == '$and'
          { key => val }
        else
          build_search(node, fields, cmd_fields)
        end
      end
      ast.flatten!
    end

    def build_query(ast, fields, cmd_fields)
      build_searches!(ast, fields, cmd_fields)
      return {} if ast == []
      return ast.first if ast.count == 1
      { '$and' => ast }
    end
  end
end
