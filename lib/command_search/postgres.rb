#  Hat.send(:where, color: "red").send(:merge, Hat.send(:where).send(:not, kind: "sombrero").send(:or, Hat.send(:where, kind: "cow"))).to_sql
# => "SELECT \"hats\".* FROM \"hats\" WHERE \"hats\".\"color\" = 'red' AND (\"hats\".\"kind\" != 'sombrero' OR \"hats\".\"kind\" = 'cow')"

require('chronic')

module CommandSearch
  module Postgres
    module_function

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
        # TODO: see if these non look ahead regexes can be used in mongo-er.
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
        bool_val = val[0] == 't' # TODO: align how mongo and this do this.
        if bool_val
          return model.where.not(field => [false, nil])
        else
          return model.where(field => [false, nil])
        end
      end

      if field_type.is_a?(Array) && field_type.include?(:allow_existence_boolean) && (val == 'true' || val == 'false')
        bool_val = val == 'true' # TODO: align how mongo and this do this.
        if bool_val
          return model.where.not(field => [false, nil])
        else
          return model.where(field => [false, nil])
        end
      end

      if search_node[:type] == :str
        return out.where("#{field} ~* ?", val)
      elsif search_node[:type] == :quoted_str
        quoted_regex = '\m' + val + '\y'
        if search_node[:value][/(^\W)|(\W$)/]
          head_border = '(^|\s|[^:+\w])'
          tail_border = '($|\s|[^:+\w])'
          quoted_regex = head_border + val + tail_border
        end
        return out.where("#{field} ~ ?", quoted_regex)
      elsif search_node[:type] == :number
        # TODO: make sure this is aligned with mongo
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
      end
    end

    def search(model, ast, fields, command_types)
      out = model.all
      # TODO: refactor this clean_ast variable so its nicer
      clean_ast = ast
      clean_ast = [ast] unless ast.is_a?(Array)
      clean_ast.each do |node|
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
          # TODO: check if negation can have multiple things in its value list.
          # TODO: look into performance of doing whole subquery as opposed to just != on each part and flipping the and/ors.
          # or using just where.not without the "IN" and not worrying about null value handling
          # sql_clause = clause.to_sql.sub(/^SELECT .* FROM .* WHERE/, '')
          # out = out.where.not(sql_clause)
          clause = search(model, node[:value].first, fields, command_types)
          out = out.where.not(id: clause)
        end
      end

      out
    end
  end
end
