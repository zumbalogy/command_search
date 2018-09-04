module CommandSearch
  module Parser
    module_function

    def parens_rindex(input)
      val_list = input.map { |x| x[:value] }
      open_i = val_list.rindex('(')
      return unless open_i
      close_offset = val_list.drop(open_i).index(')')
      return unless close_offset
      [open_i, close_offset + open_i]
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
      binary = (cluster_type == :binary)
      out = input
      out = out[:value] while out.is_a?(Hash)
      out.compact!
      # rindex (vs index) important for nested prefixes
      while (i = out.rindex { |x| x[:type] == type })
        val = [out[i + 1]]
        val.unshift(out[i - 1]) if binary && i > 0
        front_offset = 0
        front_offset = 1 if binary && i > 0
        out[(i - front_offset)..(i + 1)] = {
          type: :nest,
          nest_type: type,
          nest_op: out[i][:value],
          value: val
        }
      end
      out.map do |x|
        next x unless x[:type] == :nest
        x[:value] = cluster(type, x[:value], cluster_type)
        x
      end
    end

    def unchain(type, input)
      input.each_index do |i|
        front = input.dig(i, :type)
        mid = input.dig(i + 1, :type)
        back = input.dig(i + 2, :type)
        if front == type && mid != type && back == type
          input.insert(i + 1, input[i + 1])
        end
      end
    end

    def clean_ununused_command_syntax(input)
      out = input.map do |x|
        next if x[:type] == :paren && x[:value].is_a?(String)
        next x unless x[:type] == :nest
        x[:value] = clean_ununused_command_syntax(x[:value])
        x
      end
      out.compact
    end

    def parse(input)
      out = input
      out = group_parens(out)
      out = cluster(:colon, out)
      out = unchain(:compare, out)
      out = cluster(:compare, out)
      out = cluster(:minus, out, :prefix)
      out = cluster(:pipe, out)
      out = clean_ununused_command_syntax(out)
      out
    end
  end
end
