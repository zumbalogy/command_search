# Hat.where(color: "red", kind: "party").explain
# SELECT "hats".* FROM "hats" WHERE "hats"."color" = $1 AND "hats"."kind" = $2 [["color", "red"], ["kind", "party"]]

# Hat.where(color: "red").or(Hat.where(kind: "party")).explain
# SELECT "hats".* FROM "hats" WHERE ("hats"."color" = $1 OR "hats"."kind" = $2) [["color", "red"], ["kind", "party"]]

# Hat.where(color: "red", kind: "sombrero").or(Hat.where(kind: "party")).explain
# SELECT "hats".* FROM "hats" WHERE ("hats"."color" = $1 AND "hats"."kind" = $2 OR "hats"."kind" = $3) [["color", "red"], ["kind", "sombrero"], ["kind", "party"]]

# Hat.where(color: "red", kind: "sombrero").or(Hat.where(color: "blue", kind: "party")).explain
# SELECT "hats".* FROM "hats" WHERE ("hats"."color" = $1 AND "hats"."kind" = $2 OR "hats"."color" = $3 AND "hats"."kind" = $4) [["color", "red"], ["kind", "sombrero"], ["color", "blue"], ["kind", "party"]]

# Hat.where(color: "red", kind: "sombrero").or(Hat.where(color: "blue", kind: "party").or(Hat.where(color: "green"))).explain
# SELECT "hats".* FROM "hats" WHERE ("hats"."color" = $1 AND "hats"."kind" = $2 OR ("hats"."color" = $3 AND "hats"."kind" = $4 OR "hats"."color" = $5)) [["color", "red"], ["kind", "sombrero"], ["color", "blue"], ["kind", "party"], ["color", "green"]]

# Client.where("created_at >= :start_date AND created_at <= :end_date", {start_date: params[:start_date], end_date: params[:end_date]})

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

#
# Hat.where(color: "red", kind: "sombrero").or(Hat.where(color: "blue", kind: "party").or(Hat.where(color: "green"))).explain
#
# Hat.where(color: "red", kind: "sombrero")
# Hat.send(:where, color: "red").send(:where, kind: "sombrero")
# Hat.send(:where, color: "red").where(Hat.send(:where, kind: "sombrero"))
#
# Hat.send(:where, color: "red").send(:where, Hat.send(:where, kind: "sombrero"))
#
# Hat.send(:where, color: "red").merge(Hat.send(:where, kind: "sombrero"))
#
#  Hat.send(:where, color: "red").merge(Hat.send(:where, kind: "sombrero").or(Hat.send(:where, kind: "cow"))).to_sql
#
#  Hat.send(:where, color: "red").merge(Hat.send(:where).send(:not, kind: "sombrero").or(Hat.send(:where, kind: "cow"))).to_sql
#
# Hat.send(:where, color: "red").send(:where, kind: "sombrero").or(Hat.where(color: "blue", kind: "party").or(Hat.where(color: "green"))).explain
#
#  Hat.send(:where, color: "red").send(:merge, Hat.send(:where).send(:not, kind: "sombrero").send(:or, Hat.send(:where, kind: "cow"))).to_sql
# => "SELECT \"hats\".* FROM \"hats\" WHERE \"hats\".\"color\" = 'red' AND (\"hats\".\"kind\" != 'sombrero' OR \"hats\".\"kind\" = 'cow')"
#
#  Hat.send(:where, color: "red")
#     .send(:merge, Hat
#                   .send(:where)
#                   .send(:not, kind: "sombrero")
#                   .send(:or, Hat
#                              .send(:where, kind: "cow"))).to_sql
#
# [[:where, { color: 'red' }],
#  [:merge, [:where, [:not, { kind: 'sombrero' }]],
#                    [:or, [:where, { kind: 'cow' }]]]]
