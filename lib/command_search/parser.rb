module CommandSearch
  module Parser
    module_function

    def group_parens!(ast)
      i = 0
      opening_idxs = []
      while i < ast.length
        next i += 1 unless ast[i][:type] == :paren
        if ast[i][:value] == '('
          opening_idxs.push(i)
          ast.delete_at(i)
          next
        end
        ast.delete_at(i)
        opening = opening_idxs.pop()
        next unless opening
        val = ast.slice(opening, i - opening)
        if val.count > 1
          ast[opening..(i - 1)] = { type: :and, value: val }
          i -= val.length
          next
        elsif val.count == 1
          ast[opening] = val.first
        end
      end
    end

    def cluster_cmds!(ast)
      i = 1
      while i < ast.length - 1
        type = ast[i][:type]
        next i += 1 unless type == :colon || type == :compare
        ast[(i - 1)..(i + 1)] = {
          type: type,
          nest_op: ast[i][:value],
          value: [ast[i - 1], ast[i + 1]]
        }
      end
    end

    def cluster_or!(ast)
      i = 0
      while i < ast.length
        type = ast[i][:type]
        cluster_or!(ast[i][:value]) if type == :and || type == :not
        next i += 1 unless type == :pipe
        if i == 0 || i == ast.length - 1
          ast.delete_at(i)
          next
        end
        val = [ast[i - 1], ast[i + 1]]
        cluster_or!(val)
        ast[i][:type] = :or
        ast[i][:value] = val
        ast.delete_at(i + 1)
        ast.delete_at(i - 1)
      end
    end

    def cluster_not!(ast)
      i = ast.length
      while i > 0
        i -= 1
        type = ast[i][:type]
        cluster_not!(ast[i][:value]) if type == :and
        next unless type == :minus
        if i == ast.length - 1
          ast.delete_at(i)
          next
        end
        ast[i][:type] = :not
        ast[i][:value] = [ast[i + 1]]
        ast.delete_at(i + 1)
      end
    end

    def unchain!(ast)
      i = 1
      while i < ast.length - 3
        left = ast[i][:type]
        right = ast[i + 2][:type]
        i += 1
        next unless left == :colon || left == :compare
        next unless right == :colon || right == :compare
        ast.insert(i, ast[i].clone())
      end
    end

    def r_merge!(ast, i)
      ast[i][:type] = :str
      return unless ast[i + 1] && ast[i + 1][:type] == :str
      ast[i][:value] = ast[i][:value] + ast[i + 1][:value]
      ast.delete_at(i + 1)
    end

    def l_merge!(ast, i)
      ast[i][:type] = :str
      return unless ast[i - 1] && ast[i - 1][:type] == :str
      ast[i][:value] = ast[i - 1][:value] + ast[i][:value]
      ast.delete_at(i - 1)
    end

    def clean!(ast)
      return unless ast.any?
      if ast[0][:type] == :colon || ast[0][:type] == :compare
        r_merge!(ast, 0)
      end
      if ast[-1][:type] == :colon || ast[-1][:type] == :compare
        l_merge!(ast, ast.length - 1)
      end
      i = 1
      while i < ast.length - 1
        next i += 1 unless ast[i][:type] == :colon || ast[i][:type] == :compare
        if ast[i + 1][:type] == :minus
          r_merge!(ast, i + 1)
        elsif ![:str, :number, :quote].include?(ast[i - 1][:type])
          r_merge!(ast, i)
        elsif ![:str, :number, :quote].include?(ast[i + 1][:type])
          l_merge!(ast, i)
        else
          i += 1
        end
      end
    end

    def parse!(ast)
      clean!(ast)
      unchain!(ast)
      cluster_cmds!(ast)
      group_parens!(ast)
      cluster_not!(ast)
      cluster_or!(ast)
      ast
    end
  end
end
