module CommandSearch
  module Postgres
    module_function

    def build_quoted_regex(input)
      str = Regexp.escape(input)
      if str[/(^\W)|(\W$)/]
        head_border = '(^|\s|[^:+\w])'
        tail_border = '($|\s|[^:+\w])'
        return head_border + str + tail_border
      end
      str.gsub!("'", "''") # TODO: this needs to be smarter, but its how to escape single quotes in postgres
      '\m' + str + '\y'
    end

    def command_search(node, negate)
      field_node = node[:value].first
      field = field_node[:value]
      search_node = node[:value].last
      val = search_node[:value]
      type = search_node[:type]
      # type = Boolean if type == :existence && val == true
      type = Boolean if type == :existence
      if type == Boolean
        false_val = "'f'"
        false_val = 0 if field_node[:field_type] == Numeric
        # val = !val if negate
        if val
          return "NOT ((#{field} = #{false_val}) OR (#{field} IS NULL))"
        end
        return "((#{field} = #{false_val}) OR (#{field} IS NULL))"
      end

      # elsif type == :existence
      #   if val
      #     "NOT (#{field} IS NULL)"
      #   else
      #     "#{field} IS NULL"
      #   end

      # TODO: this does not handle time

      op = '='
      if type == :quote
        # "#{field} ~ '#{build_quoted_regex(search_node[:original_value])}'"
        val =  "'#{build_quoted_regex(search_node[:original_value])}'"
        op = '~'
      elsif type == :str
        # "#{field} ~* '#{Regexp.escape(search_node[:original_value])}'"
        val = "'#{Regexp.escape(search_node[:original_value])}'"
        op = '~*'
      elsif type == :number
        # "#{field} = #{val}"
      elsif type == Time
        return '0 = 1' unless val
        return "(#{field} >= '#{val[0]}') AND (#{field} < '#{val[1]}') AND (#{field} IS NOT NULL)"
      end
      # if negate
      #   # flip_ops = { '=' => '!=', '~' => '!~', '>' => '<=', '>=' => '<'}
      #   op = "!#{op}"
      # end
      return "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL)"
      if negate
        return "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL)"
      end
      "#{field} #{op} #{val}"
    end

    def compare_search(node, negate)
      field_node = node[:value].first
      field = field_node[:value]
      search_node = node[:value].last
      val = search_node[:value]
      type = search_node[:type]
      op = node[:nest_op]
      # if negate
      #   flip_ops = { '<' => '>=', '<=' => '>', '>' => '<=', '>=' => '<'}
      #   op = flip_ops[op]
      # end
      if node[:compare_across_fields]
        "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL) AND (#{val} IS NOT NULL)"
      elsif type == Time && val
        "(#{field} #{op} '#{val}') AND (#{field} IS NOT NULL)"
      elsif val.is_a?(Numeric) || val == val.to_i.to_s || val == val.to_f.to_s
        "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL)"
      else
        "0 = 1"
      end
    end

    def build_query(ast, negate = false)
      out = []
      ast = [ast] unless ast.is_a?(Array)
      ast.each do |node|
        type = node[:type]
        if type == :colon
          out.push(command_search(node, negate))
        elsif type == :compare
          out.push(compare_search(node, negate))
        elsif type == :and
          node[:value].each { |x| out.push(build_query(x, negate)) }
        elsif type == :or
          clauses = node[:value].map { |x| build_query(x, negate) }
          clause = clauses.join(' OR ')
          out.push("(#{clause})")
        elsif type == :not
          # negate = !negate
          # clauses = node[:value].map { |x| build_query(x, negate) }
          # clause = clauses.join(' OR ')
          # out.push("(#{clause})")
          clause = build_query(node[:value], !negate)
          out.push("NOT (#{clause})")
        end
      end
      out.join(' AND ')
    end
  end
end
