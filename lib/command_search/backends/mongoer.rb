module CommandSearch
  module Mongoer
    module_function

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

    def build_compare(node)
      op_map = { '<' => '$lt', '>' => '$gt', '<=' => '$lte', '>=' => '$gte' }
      op = op_map[node[:nest_op]]
      key = node[:value][0][:value]
      val = node[:value][1][:value]
      if node[:compare_across_fields]
        val = '$' + val
        key = '$' + key
        val = [key, val]
        key = '$expr'
      end
      { key => { op => val } }
    end

    def build_searches!(ast)
      mongo_types = { and: '$and', or: '$or', not: '$nor' }
      ast.map! do |node|
        type = node[:type]
        if type == :colon
          build_command(node)
        elsif type == :compare
          build_compare(node)
        elsif key = mongo_types[type]
          build_searches!(node[:value])
          val = node[:value]
          if key == '$nor' && val.count > 1
            next { key => [{ '$and' => val }] }
          end
          val.map! { |x| x['$or'] || x }.flatten! unless key == '$and'
          { key => val }
        end
      end
      ast.flatten!
    end

    def build_query(ast)
      build_searches!(ast)
      return {} if ast == []
      return ast.first if ast.count == 1
      { '$and' => ast }
    end
  end
end
