module CommandSearch
  module Memory
    module_function

    def command_check(item, val)
      cmd = val[0][:value]
      search = val[1][:value]
      item_val = item[cmd.to_sym] || item[cmd.to_s]
      type = val[1][:type]
      type = Boolean if type == :existence && search == true
      if type == Boolean
        !!item_val == search
      elsif type == :existence
        item_val == nil
      elsif !item_val
        return false
      elsif search.is_a?(Regexp)
        item_val.to_s[search]
        # for versions ruby 2.4.0 (2016-12-25) and up, match? is much faster
        # item_val.to_s.match?(search)
      elsif type == Time
        item_time = item_val.to_time
        search.first <= item_time && item_time < search.last
      else
        item_val == search
      end
    end

    def compare_check(item, node)
      cmd_val = node[:value].first[:value]
      item_val = item[cmd_val.to_sym] || item[cmd_val.to_s]
      return unless item_val
      val = node[:value].last[:value]
      if val.is_a?(Time)
        item_val = item_val.to_time
      elsif node[:compare_across_fields]
        val = item[val.to_sym] || item[val.to_s]
      end
      return unless val
      fn = node[:nest_op].to_sym.to_proc
      fn.call(item_val.to_f, val.to_f)
    end

    def check(item, ast)
      ast.all? do |node|
        val = node[:value]
        case node[:type]
        when :colon
          command_check(item, val)
        when :compare
          compare_check(item, node)
        when :not
          !val.all? { |v| check(item, [v]) }
        when :or
          val.any? { |v| check(item, [v]) }
        when :and
          val.all? { |v| check(item, [v]) }
        end
      end
    end
  end
end
