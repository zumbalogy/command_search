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
        input[i][:type] = :or
        input[i][:value] = val
        input.delete_at(i + 1)
        input.delete_at(i - 1)
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
        input[i][:type] = :not
        input[i][:value] = [input[i + 1]]
        input.delete_at(i + 1)
      end
    end

    def unchain!(input)
      i = 1
      while i < input.length - 3
        left = input[i][:type]
        right = input[i + 2][:type]
        i += 1
        next unless left == :colon || left == :compare
        next unless right == :colon || right == :compare
        input.insert(i, input[i].clone())
      end
    end

    def r_merge!(input, i)
      input[i][:type] = :str
      return unless input[i + 1] && input[i + 1][:type] == :str
      input[i][:value] = input[i][:value] + input[i + 1][:value]
      input.delete_at(i + 1)
    end

    def l_merge!(input, i)
      input[i][:type] = :str
      return unless input[i - 1] && input[i - 1][:type] == :str
      input[i][:value] = input[i - 1][:value] + input[i][:value]
      input.delete_at(i - 1)
    end

    def clean!(input)
      return unless input.any?
      if input[0][:type] == :colon || input[0][:type] == :compare
        r_merge!(input, 0)
      end
      if input[-1][:type] == :colon || input[-1][:type] == :compare
        l_merge!(input, input.length - 1)
      end
      i = 1
      while i < input.length - 1
        next i += 1 unless input[i][:type] == :colon || input[i][:type] == :compare
        if input[i + 1][:type] == :minus
          r_merge!(input, i + 1)
        elsif ![:str, :number, :quote].include?(input[i - 1][:type])
          r_merge!(input, i)
        elsif ![:str, :number, :quote].include?(input[i + 1][:type])
          l_merge!(input, i)
        else
          i += 1
        end
      end
    end

    def parse!(input)
      clean!(input)
      unchain!(input)
      cluster_cmds!(input)
      group_parens!(input)
      cluster_not!(input)
      cluster_or!(input)
      input
    end
  end
end
