require('chronic')

module CommandSearch
  module ActiveRecordPostgres
    module_function

    def convert_time(raw_val)
      time_str = raw_val.tr('_.-', ' ')
      if time_str == time_str.to_i.to_s
        date_begin = Time.utc(time_str) # TODO: rethink the UTC of this.
        date_end = Time.utc(time_str.to_i + 1).yesterday
      else
        date = Chronic.parse(time_str, guess: nil) || Chronic.parse(raw_val, guess: nil)
        return unless date
        date_begin = date.begin
        date_end = date.end
      end
      [date_begin, date_end]
    end

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

    def str_search(model, node, fields)
      val = Regexp.escape(node[:value]) # needs more sanitation
      clauses = fields.map { |f| "(#{f} ~* '#{val}')" }
      '(' + clauses.join(' OR ') + ')'
    end

    def number_search(model, node, fields)
      val = Regexp.escape(node[:value])
      clauses = fields.map { |f| "(CAST(#{f} as TEXT) ~ '#{val}')" }
      '(' + clauses.join(' OR ') + ')'
    end

    def quoted_search(model, node, fields)
      val = build_quoted_regex(node[:value])
      clauses = fields.map { |f| "(#{f} ~ '#{val}')" } # TODO: work on this replacement thing
      '(' + clauses.join(' OR ') + ')'
    end

    def command_search(model, node, command_types)
      field = node[:value].first[:value]
      search_node = node[:value].last
      val = search_node[:value]

      field_type = command_types[field.to_sym]
      existence_bool = false

      if field_type.is_a?(Array)
        existence_bool = field_type.include?(:allow_existence_boolean) && (val == 'true' || val == 'false')
        field_type = (field_type - [:allow_existence_boolean]).first
      end

      if field_type == Boolean || existence_bool
        bool_val = val[0] == 't'
        false_val = "'f'"
        false_val = 0 if [Numeric, Integer].include?(field_type)
        if bool_val
          "NOT ((#{field} = #{false_val}) OR (#{field} IS NULL))"
        else
          "((#{field} = #{false_val}) OR (#{field} IS NULL))"
        end
      elsif [Numeric, Integer].include?(field_type)
        "#{field} = #{val}"
      elsif [Date, Time, DateTime].include?(field_type)
        (date_begin, date_end) = convert_time(search_node[:value])
        "(fav_date >= '#{date_begin}') AND (fav_date <= '#{date_end}')"
      elsif field_type == String
        if search_node[:type] == :quoted_str
          "#{field} ~ '#{build_quoted_regex(val)}'"
        else
          "#{field} ~* '#{Regexp.escape(val)}'"
        end
      end
    end

    def compare_search(model, node, command_types)
      (first_node, last_node) = node[:value]
      key = first_node[:value]
      val = last_node[:value]
      op = node[:nest_op]

      if command_types.keys.include?(val.to_sym)
        flip_ops = { '<' => '>', '>' => '<' }
        (key, val) = [val, key]
        op[0] = flip_ops[op[0]]
      end

      type = command_types[key.to_sym]

      if type.is_a?(Array)
        type = (type - [:allow_existence_boolean]).first
      end

      sanitized_key = model.connection.quote_column_name(key)

      if command_types[val.to_sym]
        sanitized_val = model.connection.quote_column_name(val)
        # TODO: test this
        # enforcing that the key and vals are in the command_types is probably enough sanitaion here. other vals could be poison though.
        "#{sanitized_key} #{op} #{sanitized_val}"
      elsif [Numeric, Integer].include?(type)
        if val == val.to_i.to_s || val == val.to_f.to_s
          "#{sanitized_key} #{op} '#{val}'"
        else
          "0 = 1"
        end
      elsif [Date, Time, DateTime].include?(type)
        # TODO: handle (and have a test for) invalid date being entered
        (date_begin, date_end) = convert_time(val)
        if op == '>' || op == '>='
          "#{sanitized_key} #{op} '#{date_begin}'" # sanitize date_begin
        else
          "#{sanitized_key} #{op} '#{date_end}'" # sanitize date_end
        end
      end
    end

    def search(model, ast, fields, command_types)
      out = []
      ast = [ast] unless ast.is_a?(Array)
      ast.each do |node|
        type = node[:nest_type] || node[:type]
        if type == :quoted_str
          out.push(quoted_search(model, node, fields))
        elsif type == :str
          out.push(str_search(model, node, fields))
        elsif type == :number
          out.push(number_search(model, node, fields))
        elsif type == :colon
          out.push(command_search(model, node, command_types))
        elsif type == :compare
          out.push(compare_search(model, node, command_types))
        elsif type == :paren
          node[:value].each { |x| out.push(search(model, x, fields, command_types)) }
        elsif type == :pipe
          clauses = node[:value].map { |child| search(model, child, fields, command_types) }
          out.push('(' + clauses.join(' OR ') + ')')
        elsif type == :minus
          clause = search(model, node[:value], fields, command_types)
          full_clause = "NOT IN (SELECT \"#{model.table_name}\".\"id\" FROM \"#{model.table_name}\" WHERE #{clause})"
          out.push(full_clause)
        end
      end
      puts out.join(' AND ')
      out.join(' AND ')
    end
  end
end
