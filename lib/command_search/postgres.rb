#  Hat.send(:where, color: "red").send(:merge, Hat.send(:where).send(:not, kind: "sombrero").send(:or, Hat.send(:where, kind: "cow"))).to_sql
# => "SELECT \"hats\".* FROM \"hats\" WHERE \"hats\".\"color\" = 'red' AND (\"hats\".\"kind\" != 'sombrero' OR \"hats\".\"kind\" = 'cow')"

require('chronic')

module CommandSearch
  module Postgres
    module_function

    def search(model, ast, fields, command_types)
      return model.all if ast.empty?

      out = model

      ast.each do |node|

        if node[:type] == :quoted_str

          str = node[:value] || ''

          # regex = "\b#{Regexp.escape(str)}\b"

          quoted_regex = '\m' + str + '\y'

          # if str[/(^\W)|(\W$)/]
          #   head_border = '(?<=^|[^:+\w])'
          #   tail_border = '(?=$|[^:+\w])'
          #   regex = head_border + Regexp.escape(str) + tail_border
          # end

          fields.each_with_index do |field, idx|
            if idx == 0
              out = out.where("#{field} ~ ?", quoted_regex)
            else
              out = out.or(model.where("#{field} ~ ?", quoted_regex))
            end
          end

        elsif node[:type] == :str
          fields.each_with_index do |field, idx|
            if idx == 0
              out = out.where("#{field} ~* ?", node[:value])
            else
              out = out.or(model.where("#{field} ~* ?", node[:value]))
            end
          end
        elsif node[:nest_type] == :colon
          field = node[:value].first[:value]
          search_node = node[:value].last
          if search_node[:type] == :str
            out = out.where("#{field} ~* ?", search_node[:value])
          elsif search_node[:type] == :quoted_str
            quoted_regex = '\m' + search_node[:value] + '\y'
            out = out.where("#{field} ~ ?", quoted_regex)
          end
        else
          binding.pry
        end
      end
      # begin
      #   puts out.to_sql
      # rescue
      #   binding.pry
      # end

      out

    end
  end
end
