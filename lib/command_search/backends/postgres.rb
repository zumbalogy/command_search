module CommandSearch
  module Postgres
    module_function

    def quote_string(str)
      # activerecord/lib/active_record/connection_adapters/abstract/quoting.rb:62
      str.gsub!('\\', '\&\&')
      str.gsub!("'", "''")
      Regexp.escape(str)
    end

    def build_quoted_regex(input)
      str = quote_string(input)
      if str[/(^\W)|(\W$)/]
        head_border = '(^|\s|[^:+\w])'
        tail_border = '($|\s|[^:+\w])'
        return head_border + str + tail_border
      end
      '\m' + str + '\y'
    end

    def command_search(node)
      field_node = node[:value].first
      field = field_node[:value]
      search_node = node[:value].last
      val = search_node[:value]
      type = search_node[:type]
      return '0 = 1' if field == '__CommandSearch_dummy_key__'
      if type == Boolean || type == :existence
        false_val = "'f'"
        false_val = 0 if field_node[:field_type] == Numeric
        if val
          return "NOT ((#{field} = #{false_val}) OR (#{field} IS NULL))"
        end
        return "((#{field} = #{false_val}) OR (#{field} IS NULL))"
      end
      if type == Time
        return '0 = 1' unless val
        return "(#{field} >= '#{val[0]}') AND (#{field} < '#{val[1]}') AND (#{field} IS NOT NULL)"
      end
      if type == :quote
        op = '~'
        val =  "'#{build_quoted_regex(val)}'"
      elsif type == :str
        op = '~*'
        val = "'#{quote_string(val)}'"
      elsif type == :number
        op = '='
      end
      "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL)"
    end

    def compare_search(node)
      field_node = node[:value].first
      field = field_node[:value]
      search_node = node[:value].last
      val = search_node[:value]
      type = search_node[:type]
      op = node[:nest_op]
      if node[:compare_across_fields]
        "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL) AND (#{val} IS NOT NULL)"
      elsif type == Time && val
        "(#{field} #{op} '#{val}') AND (#{field} IS NOT NULL)"
      elsif val.is_a?(Numeric) || val == val.to_i.to_s || val == val.to_f.to_s
        "(#{field} #{op} #{val}) AND (#{field} IS NOT NULL)"
      else
        '0 = 1'
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
          out.push(build_query(node[:value]))
        elsif type == :or
          clauses = node[:value].map { |x| build_query(x) }
          clause = clauses.join(' OR ')
          out.push("(#{clause})")
        elsif type == :not
          clause = build_query(node[:value])
          out.push("NOT (#{clause})")
        end
      end
      out.join(' AND ')
    end
  end
end
