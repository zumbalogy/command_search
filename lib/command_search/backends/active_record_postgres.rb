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

    def build_quoted_regex(input)
      str = Regexp.escape(input || '') # TODO: see if OR can be removed
      if str[/(^\W)|(\W$)/]
        head_border = '(^|\s|[^:+\w])'
        tail_border = '($|\s|[^:+\w])'
        return head_border + str + tail_border
      end
      '\m' + str + '\y'
    end

    def str_search(model, node, fields)
      val = Regexp.escape(node[:value])
      out = model.where("#{fields.first} ~* ?", val)
      fields.drop(1).each do |field|
        out.or!(model.where("#{field} ~* ?", val))
      end
      out
    end

    def number_search(model, node, fields)
      # TODO: this might be a better way to do the mongo thing, if casting is allowed and not too slow.
      # TODO: look into performance cost of casting.
      val = Regexp.escape(node[:value])
      out = model.where("CAST(#{fields.first} as TEXT) ~ ?", val)
      fields.drop(1).each do |field|
        out.or!(model.where("CAST(#{field} as TEXT) ~ ?", val))
      end
      out
    end

    def quoted_search(model, node, fields)
      val = build_quoted_regex(node[:value])
      out = model.where("#{fields.first} ~ ?", val)
      fields.each do |field|
        out.or!(model.where("#{field} ~ ?", val))
      end
      out
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
          model.where("#{field} ~ ?", build_quoted_regex(val))
        else
          model.where("#{field} ~* ?", Regexp.escape(val))
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
          or_acc = search(model, node[:value].first, fields, command_types)
          node[:value].drop(1).each do |child|
            or_acc.or!(search(model, child, fields, command_types))
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
