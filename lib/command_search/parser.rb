module CommandSearch
  module Parser
    module_function

    def parens_rindex(input)
      open_i = input.rindex { |x| x[:value] == '(' && x[:type] == :paren }
      return unless open_i
      close_offset = input.drop(open_i).index { |x| x[:value] == ')' && x[:type] == :paren }
      return unless close_offset
      [open_i, close_offset + open_i]
    end

    def group_parens!(input)
      while parens_rindex(input)
        (a, b) = parens_rindex(input)
        val = input[(a + 1)..(b - 1)]
        input[a..b] = { type: :nest, nest_type: :paren, value: val }
      end
    end

    def cluster!(type, input, cluster_type = :binary)
      binary = (cluster_type == :binary)
      input.compact!
      # rindex (vs index) important for nested prefixes
      while (i = input.rindex { |x| x[:type] == type })
        val = [input[i + 1]]
        val.unshift(input[i - 1]) if binary && i > 0
        front_offset = 0
        front_offset = 1 if binary && i > 0
        input[(i - front_offset)..(i + 1)] = {
          type: :nest,
          nest_type: type,
          nest_op: input[i][:value],
          value: val
        }
      end
      input.each do |x|
        cluster!(type, x[:value], cluster_type) if x[:type] == :nest
      end
    end

    def unchain!(types, input)
      i = 0
      while i < input.length - 2
        left = input[i][:type]
        right = input[i + 2][:type]
        if types.include?(left) && types.include?(right)
          input.insert(i + 1, input[i + 1])
        end
        i += 1
      end
    end

    def merge_strs(input, (x, y))
      if input[y] && input[y][:type] == :str
        values = input.map { |x| x[:value] }
        { type: :str, value: values.join() }
      else
        input[x][:type] = :str
        input
      end
    end

    def clean_ununusable!(input)
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
      input.reject! { |x| x[:type] == :paren && x[:value].is_a?(String) }
    end

    def parse!(input)
      clean_ununusable!(input)
      unchain!([:colon, :compare], input)
      group_parens!(input)
      cluster!(:colon, input)
      cluster!(:compare, input)
      cluster!(:minus, input, :prefix)
      cluster!(:pipe, input)
      clean_ununused!(input)
      input
    end
  end
end
