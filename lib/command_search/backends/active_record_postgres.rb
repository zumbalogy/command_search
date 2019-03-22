require('chronic')

module CommandSearch
  module ActiveRecordPostgres
    module_function

    def convert_time(raw_val)
      time_str = raw_val.tr('_.-', ' ')
      if time_str == time_str.to_i.to_s
        date_begin = Time.utc(time_str)
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
      out = model.all
      field = node[:value].first[:value]
      search_node = node[:value].last
      val = Regexp.escape(search_node[:value])

      field_type = command_types[field.to_sym]
      if field_type == Boolean
        bool_val = val[0] == 't'
        if bool_val
          return model.where.not(field => [false, nil])
        else
          return model.where(field => [false, nil])
        end
      end

      if field_type.is_a?(Array) && field_type.include?(:allow_existence_boolean) && (val == 'true' || val == 'false')
        bool_val = val == 'true'
        if bool_val
          return model.where.not(field => [false, nil])
        else
          return model.where(field => [false, nil])
        end
      end

      if field_type.is_a?(Array)
        field_type = (field_type - [:allow_existence_boolean]).first
      end

      if [Date, Time, DateTime].include?(field_type)
        (date_begin, date_end) = convert_time(search_node[:value])
        return model.where("#{field} >= ?", date_begin).where("#{field} <= ?", date_end) # TODO: sanitize this key variable. could be original value flipped.
      elsif field_type == String
        if search_node[:type] == :quoted_str
          quoted_regex = '\m' + val + '\y'
          if search_node[:value][/(^\W)|(\W$)/]
            head_border = '(^|\s|[^:+\w])'
            tail_border = '($|\s|[^:+\w])'
            quoted_regex = head_border + val + tail_border
          end
          return out.where("#{field} ~ ?", quoted_regex)
        else
          return out.where("#{field} ~* ?", val)
        end
      elsif [Numeric, Integer].include?(field_type)
        return out.where(field => val)
      end
    end

    def compare_search(model, node, command_types)
      out = model.all

      flip_ops = {
        '<' => '>',
        '>' => '<',
        '<=' => '>=',
        '>=' => '<='
      }

      (first_node, last_node) = node[:value]
      key = first_node[:value]
      val = last_node[:value]
      op = node[:nest_op]

      if command_types.keys.include?(val.to_sym)
        (key, val) = [val, key]
        op = flip_ops[op]
      end

      raw_type = command_types[key.to_sym]

      if raw_type.is_a?(Array)
        type = (raw_type - [:allow_existence_boolean]).first
      else
        type = raw_type
      end

      # TODO: should guarantee that type is found. (this might be done in dealiaser).

      if command_types[val.to_sym]
        return model.where("#{key} #{op} #{val}") # TODO: sanitize this key and val variable.
      elsif type == Numeric
        return model.where("#{key} #{op} ?", val) # TODO: sanitize this key variable. could be original value flipped.
      elsif [Date, Time, DateTime].include?(type)
        (date_begin, date_end) = convert_time(val)
        if op == '>' || op == '>='
          return model.where("#{key} #{op} ?", date_begin) # TODO: sanitize this key variable. could be original value flipped.
        else
          return model.where("#{key} #{op} ?", date_end) # TODO: sanitize this key variable. could be original value flipped.
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