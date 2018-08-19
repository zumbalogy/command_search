require('chronic')

class Memory
  class << self

    def check(item, ast, fields, command_types)
      # TODO: break this into fns and make clean
      field_vals = fields.map { |x| item[x] }.compact
      ast.all? do |node|
        val = node[:value]
        if node[:nest_type] == :pipe
          val.any? { |v| check(item, v.kind_of?(Array) ? v : [v], fields, command_types) }
        elsif node[:nest_type] == :minus
          !val.any? { |v| check(item, v.kind_of?(Array) ? v : [v], fields, command_types) }
        elsif node[:nest_type] == :paren
          val.all? { |v| check(item, v.kind_of?(Array) ? v : [v], fields, command_types) }
        elsif node[:nest_type] == :compare
          fn = node[:nest_op].to_sym.to_proc
          args = val.map { |v| v[:type] == :number ? v[:value] : item[v[:value].to_sym] }
          return unless args.all?
          fn.call(*args.map(&:to_f))
        elsif node[:nest_type] == :colon
          # TODO: make it indiffernt access
          cmd = val[0][:value].to_sym
          cmd_search = val[1][:value]
          cmd_type = command_types[cmd]
          return unless cmd_type
          if cmd_type == Boolean
            if cmd_search == 'true'
              item[cmd]
            else
              item[cmd] == false
            end
          elsif [cmd_type].flatten.include?(:allow_existence_boolean) && (cmd_search == 'true' || cmd_search == 'false')
            # TODO: test and handle uppercase/other-casings of True.
            if cmd_search == 'true'
              item[cmd]
            else
              item[cmd] == nil
            end
          elsif !item.key?(cmd)
            return false
          elsif val[1][:type] == :str
            # TODO: test and look into this being order independant or change api for allow_existence_boolean
            item[cmd][/#{Regexp.escape(cmd_search)}/mi]
          else
            # TODO: This should maybe not do to_s and handle differnt declared types of it seperate, for error messaging and all.
            # or maybe adding a dynamic type should be allowed and defaulted.
            item[cmd].to_s[/\b#{Regexp.escape(cmd_search)}\b/]
          end
        elsif node[:type] == :quoted_str
          field_vals.any? { |x| x[/\b#{Regexp.escape(val)}\b/]}
        else
          field_vals.any? { |x| x[/#{Regexp.escape(val)}/mi] }
        end
      end
    end

    def build_query(ast, fields, command_types = {})
      proc { |x| check(x, ast, fields, command_types) }
    end
  end
end
