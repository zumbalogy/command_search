module CommandSearch
  module Parser
    module_function

    def group_parens!(input)
      i = 0
      opening_idxs = []
      while i < input.length
        next i += 1 unless input[i][:type] == :paren
        if input[i][:value] == '('
          opening_idxs.push(i)
        elsif opening = opening_idxs.pop()
          val = input[(opening + 1)..(i - 1)]
          input[opening..i] = { type: :nest, nest_type: :paren, value: val }
          i -= (val.length + 1)
        end
        i += 1
      end
    end

    def cluster!(type, input, cluster_type = :binary)
      binary = (cluster_type == :binary)
      i = input.length - 1
      while i >= 0
        if input[i][:type] == type
          val = [input[i + 1]]
          val.compact!
          val.unshift(input[i - 1]) if binary && i > 0
          front_offset = 0
          front_offset = 1 if binary && i > 0
          input[(i - front_offset)..(i + 1)] = {
            type: :nest,
            nest_type: type,
            nest_op: input[i][:value],
            value: val
          }
          i -= 1 if binary
        end
        cluster!(type, input[i][:value], cluster_type) if input[i][:type] == :nest
        i -= 1
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
