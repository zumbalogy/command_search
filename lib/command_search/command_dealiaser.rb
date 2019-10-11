module CommandSearch
  module CommandDealiaser
    module_function

    def cast_bool(type, node)
      if type == Boolean
        node[:type] = Boolean
        node[:value] = !!node[:value][0][/t/i]
        return
      end
      return unless type.is_a?(Array) && type.include?(:allow_existence_boolean)
      return unless node[:type] == :str && node[:value][/\Atrue\Z|\Afalse\Z/i]
      node[:type] = :existence
      node[:value] = !!node[:value][0][/t/i]
    end

    def cast_type(type, node)
      cast_bool(type, node)
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
      # here I will take all the :allow_existence_booleans out of the alaises. but should be frozen.
      # maybe seperate step
      # maybe combine all these steps and call it normalize or such.
    end

    def clean_command_fields(aliases)
      out = {}
      aliases.each do |k, v|
        next if v.is_a?(Symbol)
        if v.is_a?(Array)
          out[k] = (v - [:allow_existence_boolean]).first
          next
        end
        next out[k] = v
      end
      out
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
