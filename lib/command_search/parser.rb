module CommandSearch
  module Parser
    module_function

    def parens_rindex(input)
      val_list = input.map { |x| x[:value] }
      open_i = input.rindex { |x| x[:value] == '(' && x[:type] == :paren}
      return unless open_i
      close_offset = input.drop(open_i).index { |x| x[:value] == ')' && x[:type] == :paren}
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

    def cluster!(type, input, cluster_type = :binary)
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
      out.map! do |x|
        next x unless x[:type] == :nest
        x[:value] = cluster!(type, x[:value], cluster_type)
        x
      end
    end

    def unchain!(types, input)
      i = 0
      while i < input.length - 2
        front = input[i][:type]
        mid = input[i + 1][:type]
        back = input[i + 2][:type]
        if types.include?(front) && !types.include?(mid) && types.include?(back)
          input.insert(i + 1, input[i + 1])
        end
        i += 1
      end
    end

    def merge_strs(input, (x, y))
      return input if input.empty?
      if input[y] && input[y][:type] == :str
        values = input.map { |x| x[:value] }
        { type: :str, value: values.join() }
      else
        input[x][:type] = :str
        input
      end
    end

    def clean_ununusable!(input)
      return unless input.any?

      i = 0
      while i < input.length
        next i += 1 unless input[i][:type] == :minus
        next i += 1 unless i > 0 && [:compare, :colon].include?(input[i - 1][:type])
        input[i..i + 1] = merge_strs(input[i..i + 1], [0, 1])
      end

      i = 0
      while i < input.length
        next i += 1 if ![:compare, :colon].include?(input[i][:type])
        next i += 1 if i > 0 &&
          (i < input.count - 1) &&
          [:str, :number, :quoted_str].include?(input[i - 1][:type]) &&
          [:str, :number, :quoted_str].include?(input[i + 1][:type])

        input[i..i + 1] = merge_strs(input[i..i + 1], [0, 1])
        input[i - 1..i] = merge_strs(input[i - 1..i], [1, 0]) if i > 0
      end

      input.select! { |x| x[:type] != :space }
      input[-1][:type] = :str if input[-1] && input[-1][:type] == :minus
    end

    def clean_ununused!(input)
      input.map! do |x|
        next if x[:type] == :paren && x[:value].is_a?(String)
        next if x[:nest_type] == :colon && x[:value].empty?
        if x[:nest_type] == :compare && x[:value].length < 2
          x = clean_ununused!(x[:value]).first
        end
        next x unless x && x[:type] == :nest
        x[:value] = clean_ununused!(x[:value])
        x
      end
      input.compact!
      input
    end

    def parse(input)
      out = input
      clean_ununusable!(out)
      unchain!([:colon, :compare], out)
      out = group_parens(out)
      cluster!(:colon, out)
      cluster!(:compare, out)
      cluster!(:minus, out, :prefix)
      cluster!(:pipe, out)
      clean_ununused!(out)
      out
    end
  end
end
