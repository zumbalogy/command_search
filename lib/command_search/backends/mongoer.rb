module CommandSearch
  module Mongoer
    module_function

    def build_regex(raw, type)
      str = Regexp.escape(raw)
      return /#{str}/i unless type == :quoted_str
      return '' if raw == ''
      return /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      Regexp.new(border_a + str + border_b)
    end

    def build_search(node, fields, command_types)
      str = node[:value] || ''
      fields = [fields] unless fields.is_a?(Array)

      forms = fields.map do |field|
        type = command_types[field.to_sym]
        if type == Numeric
          { field => str }
        else
          { field => build_regex(str, node[:type]) }
        end
      end
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def build_command(node, command_types)
      (field_node, search_node) = node[:value]
      key = field_node[:value]
      type = command_types[key.to_sym]

      raw_val = search_node[:value]
      search_type = search_node[:type]
      search_type = Boolean if search_type == :existence && raw_val == true


      if search_type == Boolean
        # These queries can return true for empty arrays.
        val = [
          { key => { '$exists' => true } },
          { key => { '$ne' => !raw_val } }
        ]
        key = '$and'
      elsif search_type == :existence
        val = { '$exists' => false }
      elsif type == String
        val = build_regex(raw_val, search_type)
      elsif type == Numeric
        val = raw_val
      elsif type == Time
        if raw_val == :__commandSeachDummyDate__
          return [{ CommandSeachDummyDate: true }, { CommandSeachDummyDate: false }]
        end
        return [
          { key => { '$gte' => raw_val[0] } },
          { key => { '$lt' => raw_val[1] } }
        ]
      end
      { key => val }
    end

    def build_compare(ast_node, command_types)
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

      mongo_op = mongo_op_map[op]
      type = command_types[key.to_sym]


      if val && val.class != Time && command_types[val.to_sym]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
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
