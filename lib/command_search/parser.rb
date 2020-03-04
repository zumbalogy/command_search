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

    def merge_right!(input, i)
      input[i][:type] = :str
      return unless input[i + 1] && input[i + 1][:type] == :str
      input[i][:value] = input[i][:value] + input[i + 1][:value]
      input.delete_at(i + 1)
    end

    def merge_left!(input, i)
      input[i][:type] = :str
      return unless input[i - 1] && input[i - 1][:type] == :str
      input[i][:value] = input[i - 1][:value] + input[i][:value]
      input.delete_at(i - 1)
    end

    def clean_ununusable!(input)
      return unless input.any?
      if [:compare, :colon].include?(input.first[:type])
        merge_right!(input, 0)
      end
      if [:compare, :colon].include?(input.last[:type])
        merge_left!(input, input.length - 1)
      end
      i = 1
      while i < input.length - 1
        next i += 1 unless [:compare, :colon].include?(input[i][:type])
        if input[i + 1][:type] == :minus
          merge_right!(input, i + 1)
        elsif ![:str, :number, :quote].include?(input[i - 1][:type])
          merge_right!(input, i)
        elsif ![:str, :number, :quote].include?(input[i + 1][:type])
          merge_left!(input, i)
        else
          i += 1
        end
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
