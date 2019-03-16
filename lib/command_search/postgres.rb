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

      if field_type.is_a?(Array) && field_type.include?(:allow_existance_boolean) && (val == 'true' || val == 'false')
        bool_val = val == 'true' # TODO: align how mongo and this do this.
        return model.where(field => bool_val)
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
        binding.pry
      end
    end

    def search(model, ast, fields, command_types)
      out = model.all
      ast.each do |node|
        if node[:type] == :quoted_str
          out.merge!(quoted_search(model, node, fields))
        elsif node[:type] == :str
          out.merge!(str_search(model, node, fields))
        elsif node[:nest_type] == :colon
          out.merge!(command_search(model, node, command_types))
        elsif node[:type] == :number
          out.merge!(number_search(model, node, fields))
        else
          binding.pry
        end
      end

      # begin; puts out.to_sql; rescue; binding.pry; end

      out
    end
  end
end
