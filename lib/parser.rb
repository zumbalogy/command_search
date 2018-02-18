class Parser
  class << self

    def parens_rindex(input)
      val_list = input.map { |x| x[:value] }
      open_i = val_list.rindex('(')
      return unless open_i
      close_i = val_list.drop(open_i).index(')') + open_i
      return unless close_i
      [open_i, close_i]
    end

    def group_parens(input)
      out = input
      while parens_rindex(out)
        (a, b) = parens_rindex(out)
        val = out[(a + 1)..(b - 1)]
        out[a..b] = { type: :nest, nest_type: :paren, value: val }
      end
      out
    end

    def cluster(type, input, cluster_type = :binary)
      binary = cluster_type == :binary
      out = input
      out = out[:value] while out.is_a?(Hash)
      i = nil
      while i = out.index { |x| x[:type] == type }
        val = [out[i + 1]]
        val.unshift(out[i - 1]) if binary
        front_offset = 0
        front_offset = 1 if binary
        out[(i - front_offset)..(i + 1)] = {
          type: :nest,
          nest_type: type,
          nest_op: out[i],
          value: val
        }
      end
      out.map do |x|
        next x unless x[:type] == :nest
        x[:value] = cluster(type, x[:value], cluster_type)
        x
      end
    end

    def parse(input)
      parens = group_parens(input)
      negate = cluster(:minus, parens, :prefix)
      colons = cluster(:colon, negate)
      compare = cluster(:compare, colons)
      pipes = cluster(:pipe, compare)
      pipes
    end
  end
end
