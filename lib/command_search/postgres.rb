#  Hat.send(:where, color: "red").send(:merge, Hat.send(:where).send(:not, kind: "sombrero").send(:or, Hat.send(:where, kind: "cow"))).to_sql
# => "SELECT \"hats\".* FROM \"hats\" WHERE \"hats\".\"color\" = 'red' AND (\"hats\".\"kind\" != 'sombrero' OR \"hats\".\"kind\" = 'cow')"

require('chronic')

module CommandSearch
  module Postgres
    module_function

    def str_search(out, model, node, fields)
      fields.each_with_index do |field, idx|
        if idx == 0
          out = out.where("#{field} ~* ?", Regexp.escape(node[:value]))
        else
          out = out.or(model.where("#{field} ~* ?", Regexp.escape(node[:value])))
        end
      end
      out
    end

    def quoted_search(out, model, node, fields)
      str = node[:value] || ''
      quoted_regex = '\m' + Regexp.escape(str) + '\y'
      # if str[/(^\W)|(\W$)/]
      #   head_border = '(?<=^|[^:+\w])'
      #   tail_border = '(?=$|[^:+\w])'
      fields.each_with_index do |field, idx|
        if idx == 0
          out = out.where("#{field} ~ ?", quoted_regex)
        else
          out = out.or(model.where("#{field} ~ ?", quoted_regex))
        end
      end
      out
    end

    def command_search(out, model, node, command_types)
      field = node[:value].first[:value]
      search_node = node[:value].last
      val = Regexp.escape(search_node[:value])
      if search_node[:type] == :str
        return out.where("#{field} ~* ?", val)
      elsif search_node[:type] == :quoted_str
        quoted_regex = '\m' + val + '\y'
        return out.where("#{field} ~ ?", quoted_regex)
      end
    end

    def search(model, ast, fields, command_types)
      out = model.all
      ast.each do |node|
        if node[:type] == :quoted_str
          out = quoted_search(out, model, node, fields)
        elsif node[:type] == :str
          out = str_search(out, model, node, fields)
        elsif node[:nest_type] == :colon
          out = command_search(out, model, node, command_types)
        else
          binding.pry
        end
      end

      # begin; puts out.to_sql; rescue; binding.pry; end

      out
    end
  end
end
