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
          input.delete_at(i)
          next
        end
        input.delete_at(i)
        opening = opening_idxs.pop()
        next unless opening
        val = input.slice(opening, i - opening)
        if val.count > 1
          input[opening..(i - 1)] = { type: :and, value: val }
          i -= val.length
          next
        elsif val.count == 1
          input[opening] = val.first
        end
      end
    end

    def cluster_cmds!(input)
      i = 1
      while i < input.length - 1
        type = input[i][:type]
        next i += 1 unless type == :colon || type == :compare
        input[(i - 1)..(i + 1)] = {
          type: type,
          nest_op: input[i][:value],
          value: [input[i - 1], input[i + 1]]
        }
      end
    end

    def cluster_or!(input)
      i = 0
      while i < input.length
        type = input[i][:type]
        cluster_or!(input[i][:value]) if type == :and || type == :not
        next i += 1 unless type == :pipe
        if i == 0 || i == input.length - 1
          input.delete_at(i)
          next
        end
        val = [input[i - 1], input[i + 1]]
        cluster_or!(val)
        input[(i - 1)..(i + 1)] = { type: :or, value: val }
      end
    end

    def cluster_not!(input)
      i = input.length
      while i > 0
        i -= 1
        type = input[i][:type]
        cluster_not!(input[i][:value]) if type == :and
        next unless type == :minus
        if i == input.length - 1
          input.delete_at(i)
          next
        end
        input[i..(i + 1)] = {
          type: :not,
          value: [input[i + 1]]
        }
      end
    end

    def unchain!(input, types)
      i = 0
      while i < input.length - 2
        left = input[i][:type]
        right = input[i + 2][:type]
        if types.include?(left) && types.include?(right)
          input.insert(i + 1, input[i + 1].clone())
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
      i = 1
      while i < input.length
        next i += 1 unless input[i][:type] == :minus
        next i += 1 unless [:compare, :colon].include?(input[i - 1][:type])
        input[i..i + 1] = merge_strs(input[i..i + 1], [0, 1])
      end
      i = 0
      while i < input.length
        next i += 1 if ![:compare, :colon].include?(input[i][:type])
        next i += 1 if i > 0 &&
          (i < input.count - 1) &&
          [:str, :number, :quote].include?(input[i - 1][:type]) &&
          [:str, :number, :quote].include?(input[i + 1][:type])

        input[i..i + 1] = merge_strs(input[i..i + 1], [0, 1])
        input[i - 1..i] = merge_strs(input[i - 1..i], [1, 0]) if i > 0
      end
    end

    def parse!(input)
      clean_ununusable!(input)
      unchain!(input, [:colon, :compare])
      cluster_cmds!(input)
      group_parens!(input)
      cluster_not!(input)
      cluster_or!(input)
      input
    end
  end
end
