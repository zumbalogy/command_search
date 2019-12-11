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

    def command_search(node)
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
        if val
          "NOT ((#{field} = #{false_val}) OR (#{field} IS NULL))"
        else
          "((#{field} = #{false_val}) OR (#{field} IS NULL))"
        end
      # elsif type == :existence
      #   if val
      #     "NOT (#{field} IS NULL)"
      #   else
      #     "#{field} IS NULL"
      #   end
      elsif type == :quote
        "#{field} ~ '#{build_quoted_regex(val)}'"
      elsif type == :str
        "#{field} ~* '#{Regexp.escape(val)}'"
      elsif type == :number
        "#{field} = #{val}"
      end
    end

    def compare_search(node)
      field_node = node[:value].first
      field = field_node[:value]
      search_node = node[:value].last
      val = search_node[:value]
      type = search_node[:type]
      op = node[:nest_op]
      if type == Time
        "#{field} #{op} '#{val}'"
      elsif val.is_a?(Numeric) || val == val.to_i.to_s || val == val.to_f.to_s
        "#{field} #{op} #{val}"
      else
        "0 = 1"
      end
    end

    def build_query(ast)
      out = []
      ast = [ast] unless ast.is_a?(Array)
      ast.each do |node|
        type = node[:type]
          if type == :colon
          out.push(command_search(node))
        elsif type == :compare
          out.push(compare_search(node))
        elsif type == :and
          node[:value].each { |x| out.push(build_query(x)) }
        elsif type == :or
          clauses = node[:value].map { |child| build_query(child) }
          out.push('(' + clauses.join(' OR ') + ')')
        elsif type == :not
          puts "this is minus and no go here"
          5 / 0
        end
      end
      out.join(' AND ')
    end
  end
end
