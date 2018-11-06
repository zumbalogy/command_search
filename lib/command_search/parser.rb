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

    def unchain!(type, input)
      (input.length - 2).times do |i|
        front = input[i][:type]
        mid = input[i + 1][:type]
        back = input[i + 2][:type]
        if front == type && mid != type && back == type
          input.insert(i + 1, input[i + 1])
        end
      end
    end

    def clean_ununusable!(input)
      return unless input.any?
      # if colon or comprare in the front or back, merge it with neighboring string or delete it
      if input[0][:type] == :colon || input[0][:type] == :compare
        if input[1] && input[1][:type] == :str
          values = input[0..1].map { |x| x[:value] }
          input[0..1] = { type: :str, value: values.join() }
        else
          input[0][:type] == :str
        end
      end
      if input[-1][:type] == :colon || input[-1][:type] == :compare
        if input[-2] && input[-2][:type] == :str
          values = input[-2..-1].map { |x| x[:value] }
          input[-2..-1] = { type: :str, value: values.join() }
        else
          input[-1][:type] == :str
        end
      end

      # if minus is after compare or colon, merge it with following string if there is one
      i = 0
      while i < input.length
        if input[i][:type] == :minus
          if input[i - 1][:type] == :compare || input[i - 1][:type] == :colon
            if input[i + 1][:type] == :str
              values = input[i..i + 1].map { |x| x[:value] }
              input[i..i + 1] = { type: :str, value: values.join() }
            else
              input[i][:type] == :str
            end
          end
        end
        i += 1
      end

      # if colon or compare dont have a string after them, turn to string
      i = 0
      while i < input.length
        if input[i][:type] == :colon || input[i][:type] == :compare
          if input[i - 1] && ![:str, :number, :quoted_str].include?(input[i - 1][:type])
            if input[i + 1] && input[i + 1][:type] == :str
              values = input[i..i + 1].map { |x| x[:value] }
              input[i..i + 1] = { type: :str, value: values.join() }
              i -= 1
            else
              input[i][:type] = :str
            end
          end
          if input[i + 1] && ![:str, :number, :quoted_str].include?(input[i + 1][:type])
            if input[i - 1][:type] == :str
              values = input[i - 1..i].map { |x| x[:value] }
              input[i - 1..i] = { type: :str, value: values.join() }
              i -= 1
            else
              input[i][:type] = :str
            end
          end
          input[i][:type] = :str unless input[i + 1]
        end
        i += 1
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
      out = group_parens(out)
      cluster!(:colon, out)
      unchain!(:compare, out)
      cluster!(:compare, out)
      cluster!(:minus, out, :prefix)
      cluster!(:pipe, out)
      out = clean_ununused!(out)
      out
    end
  end
end
