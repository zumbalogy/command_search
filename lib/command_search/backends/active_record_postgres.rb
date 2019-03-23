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
        date_begin = date.begin
        date_end = date.end
      end
      [date_begin, date_end]
    end

    def str_search(model, node, fields)
      out = model.all
      fields.each_with_index do |field, idx|
        if idx == 0
          out = out.where("#{field} ~* ?", Regexp.escape(node[:value]))
        else
          out = out.or(model.where("#{field} ~* ?", Regexp.escape(node[:value])))
        end
      end
      out
    end

    def number_search(model,node, fields)
      out = model.all
      fields.each_with_index do |field, idx|
        if idx == 0
          # TODO: look into performance cost of this.
          out = out.where("CAST(#{field} as TEXT) ~* ?", Regexp.escape(node[:value]))
        else
          out = out.or(model.where("CAST(#{field} as TEXT) ~* ?", Regexp.escape(node[:value])))
        end
      end
      out
    end

    def quoted_search(model, node, fields)
      out = model.all
      str = node[:value] || ''
      quoted_regex = '\m' + Regexp.escape(str) + '\y'
      if str[/(^\W)|(\W$)/]
        head_border = '(^|\s|[^:+\w])'
        tail_border = '($|\s|[^:+\w])'
        quoted_regex = head_border + Regexp.escape(str) + tail_border
      end
      fields.each_with_index do |field, idx|
        if idx == 0
          out = out.where("#{field} ~ ?", quoted_regex)
        else
          out = out.or(model.where("#{field} ~ ?", quoted_regex))
        end
      end
      out
    end

    def command_search(model, node, command_types)
      field = node[:value].first[:value]
      search_node = node[:value].last
      val = Regexp.escape(search_node[:value])

      full_field_type = command_types[field.to_sym]

      if full_field_type.is_a?(Array)
        field_type = (full_field_type - [:allow_existence_boolean]).first
      else
        field_type = full_field_type
      end

      if field_type == Boolean
        bool_val = val[0] == 't'
        if bool_val
          model.where.not(field => [false, nil])
        else
          model.where(field => [false, nil])
        end
      elsif full_field_type.is_a?(Array) && full_field_type.include?(:allow_existence_boolean) && (val == 'true' || val == 'false')
        bool_val = val == 'true'
        if bool_val
          model.where.not(field => [false, nil])
        else
          model.where(field => [false, nil])
        end
      elsif [Numeric, Integer].include?(field_type)
        model.where(field => val)
      elsif [Date, Time, DateTime].include?(field_type)
        (date_begin, date_end) = convert_time(search_node[:value])
        model.where("#{field} >= ?", date_begin).where("#{field} <= ?", date_end)
      elsif field_type == String
        if search_node[:type] == :quoted_str
          quoted_regex = '\m' + val + '\y'
          if search_node[:value][/(^\W)|(\W$)/]
            head_border = '(^|\s|[^:+\w])'
            tail_border = '($|\s|[^:+\w])'
            quoted_regex = head_border + val + tail_border
          end
          model.where("#{field} ~ ?", quoted_regex)
        else
          model.where("#{field} ~* ?", val)
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
        model.where("#{sanitized_key} #{op} #{sanitized_val}")
      elsif type == Numeric
        model.where("#{sanitized_key} #{op} ?", val)
      elsif [Date, Time, DateTime].include?(type)
        (date_begin, date_end) = convert_time(val)
        if op == '>' || op == '>='
          model.where("#{sanitized_key} #{op} ?", date_begin)
        else
          model.where("#{sanitized_key} #{op} ?", date_end)
        end
      end
    end

    def search(model, ast, fields, command_types)
      out = model.all
      ast = [ast] unless ast.is_a?(Array)
      ast.each do |node|
        type = node[:nest_type] || node[:type]
        if type == :quoted_str
          out.merge!(quoted_search(model, node, fields))
        elsif type == :str
          out.merge!(str_search(model, node, fields))
        elsif type == :number
          out.merge!(number_search(model, node, fields))
        elsif type == :colon
          out.merge!(command_search(model, node, command_types))
        elsif type == :compare
          out.merge!(compare_search(model, node, command_types))
        elsif type == :paren
          node[:value].each { |x| out.merge!(search(model, x, fields, command_types)) }
        elsif type == :pipe
          or_acc = model.all
          node[:value].each_with_index do |child, index|
            clause = search(model, child, fields, command_types)
            if index == 0
              or_acc.merge!(clause)
            else
              or_acc.or!(clause)
            end
          end
          out.merge!(or_acc)
        elsif type == :minus
          # TODO: look into performance of doing whole subquery as opposed to just != on each part and flipping the and/ors.
          # or using just where.not without the "IN" and not worrying about null value handling
          # sql_clause = clause.to_sql.sub(/^SELECT .* FROM .* WHERE/, '')
          # out = out.where.not(sql_clause)
          clause = search(model, node[:value], fields, command_types)
          out = out.where.not(id: clause)
        end
      end
      out
    end
  end
end
