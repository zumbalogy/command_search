class Parser

  ## order of operations:
  # group parens
  # negate
  # colons
  # ors

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
      out = input.clone()
      while parens_rindex(out)
        (a, b) = parens_rindex(out)
        val = out[(a + 1)..(b - 1)]
        out[a..b] = { type: :nest, nest_type: :paren, value: val }
      end
      out
    end

    def group_negate(input)
      out = input.clone()
      out = out[:value] while out.is_a?(Hash)
      while out.index { |x| x[:type] == :minus }
        i = out.index { |x| x[:type] == :minus }
        val = out[i + 1]
        out[i..(i + 1)] = { type: :nest, nest_type: :minus, value: val }
      end
      out.map do |x|
        x[:value] = group_negate(x[:value]) if x[:type] == :nest
        x
      end
    end

    def group_colons(input)
      out = input.clone()
      while out.index { |x| x[:type] == :colon }
        i = out.index { |x| x[:type] == :colon }
        val = [out[i - 1], out[i + 1]]
        out[(i - 1)..(i + 1)] = { type: :nest, nest_type: :colon, value: val }
      end
      out.map do |x|
        x[:value] = group_colons(x[:value]) if x[:type] == :nest
        x
      end
    end

    def group_pipes(input)
      out = input.clone()
      while out.index { |x| x[:type] == :pipe }
        i = out.index { |x| x[:type] == :pipe }
        val = [out[i - 1], out[i + 1]]
        out[(i - 1)..(i + 1)] = { type: :nest, nest_type: :pipe, value: val }
      end
      out.map do |x|
        x[:value] = group_colons(x[:value]) if x[:type] == :nest
        x
      end
    end

    def parse(input)
      parens = group_parens(input)
      negate = group_negate(parens)
      colons = group_colons(negate)
      pipes = group_pipes(colons)
      pipes
    end
  end
end
