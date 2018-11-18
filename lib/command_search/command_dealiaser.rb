module CommandSearch
  module CommandDealiaser
    module_function

    def dealias_key(key, aliases)
      key = aliases[key.to_sym] while aliases[key.to_sym].is_a?(Symbol)
      key.to_s
    end

    def dealias_values((key_node, search_node), aliases)
      new_key = dealias_key(key_node[:value], aliases)
      key_node[:value] = new_key
      [key_node, search_node]
    end

    def unnest_unaliased(node, aliases)
      type = node[:nest_type]
      values = node[:value].map { |x| x[:value].to_sym }
      return node if type == :colon && aliases[values.first]
      return node if type == :compare && (values & aliases.keys).any?
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
