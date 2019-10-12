module CommandSearch
  module Mongoer
    module_function

    def build_search(node, fields, command_types)
      val = node[:value]
      forms = fields.map do |field|
        type = command_types[field.to_sym]
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

    def build_compare(node, command_types)
      op_map = {
        '<' => '$lt',
        '>' => '$gt',
        '<=' => '$lte',
        '>=' => '$gte'
      }
      key = node[:value][0][:value]
      val = node[:value][1][:value]
      op = op_map[node[:nest_op]]
      if val.class == String && command_types[val.to_sym]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
      end
      { key => { op => val } }
    end

    def build_searches!(ast, fields, command_types)
      ast.map! do |x|
        type = x[:nest_type]
        if type == :colon
          build_command(x)
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
      ast.map! do |node|
        key = mongo_types[node[:nest_type]]
        next node unless key
        build_tree!(node[:value])
        if key == '$nor' && node[:value].count > 1
          node = { key => [{ '$and' => node[:value] }] }
        else
          node = { key => node[:value] }
        end
        node['$or'].map! { |x| x['$or'] || x }.flatten! if node['$or']
        node['$nor'].map! { |x| x['$or'] || x }.flatten! if node['$nor']
        node
      end
    end

    def build_query(ast, fields, command_types)
      build_searches!(ast, fields, command_types)
      build_tree!(ast)
      return {} if ast == []
      return ast.first if ast.count == 1
      { '$and' => ast }
    end
  end
end
