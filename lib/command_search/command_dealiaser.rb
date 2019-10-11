module CommandSearch
  module CommandDealiaser
    module_function

    def is_bool_str?(type, node)
      return true if type == Boolean
      return false unless type.is_a?(Array) && type.include?(:allow_existence_boolean)
      return false unless node[:type] == :str
      # TODO: tests with quoted string
      node[:value][/\Atrue\Z|\Afalse\Z/i]
    end

    def make_bool(str)
      !!str[0][/t/i]
    end

    def cast_type(type, node)
      return node[:value] = make_bool(node[:value]) if is_bool_str?(type, node)
    end

    def dealias_key(key, aliases)
      key = aliases[key.to_sym] while aliases[key.to_sym].is_a?(Symbol)
      key.to_s
    end

    def dealias_values((key_node, search_node), aliases)
      new_key = dealias_key(key_node[:value], aliases)
      type = aliases[new_key.to_sym]
      cast_type(type, search_node) if type
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

    def dealias(ast, aliases)
      ast.map! do |x|
        next x unless x[:nest_type]
        dealias(x[:value], aliases)
        next x unless [:colon, :compare].include?(x[:nest_type])
        x[:value] = dealias_values(x[:value], aliases)
        x
      end
    end

    def decompose_unaliasable(ast, aliases)
      ast.map! do |x|
        next x unless x[:nest_type]
        decompose_unaliasable(x[:value], aliases)
        next x unless [:colon, :compare].include?(x[:nest_type])
        unnest_unaliased(x, aliases)
      end
    end
  end
end
