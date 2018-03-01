class Dealiaser
  class << self

    def dealias_key(key, aliases)
      while aliases[key.to_sym].is_a?(Symbol)
        key = aliases[key.to_sym]
      end
      key.to_s
    end

    def dealias_values((key_node, seach_node), aliases)
      new_key = dealias_key(key_node[:value], aliases)
      key_node[:value] = new_key
      [key_node, seach_node]
    end

    def dealias(ast, aliases)
      ast.flat_map do |x|
        n_type = x[:nest_type]
        next x unless n_type
        x[:value] = dealias(x[:value], aliases)
        next x unless [:colon, :compare].include?(n_type)
        x[:value] = dealias_values(x[:value], aliases)
        x
      end
    end
  end
end
