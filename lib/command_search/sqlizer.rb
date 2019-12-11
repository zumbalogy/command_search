module CommandSearch
  module Sqlizer
    module_function

    def clean_comparison!(node, fields)
      val = node[:value]
      return unless fields[val[1][:value].to_sym]
      if fields[val[0][:value].to_sym]
        node[:compare_across_fields] = true
        return
      end
      flip_ops = { '<' => '>', '>' => '<', '<=' => '>=', '>=' => '<=' }
      node[:nest_op] = flip_ops[node[:nest_op]]
      node[:value].reverse!
    end

    def dealias_key(key, fields)
      key = fields[key.to_sym] while fields[key.to_sym].is_a?(Symbol)
      key
    end

    def split_general_fields(node, fields)
      general_fields = fields.select { |k, v| v.is_a?(Hash) && v[:general_search] }.keys
      general_fields = ['__CommandSearch_dummy_key__'] if general_fields.empty?
      new_val = general_fields.map! do |field|
        {
          type: :colon,
          value: [
            { value: field.to_s },
            { value: node[:value], type: node[:type] }
          ]
        }
      end
      return new_val.first if new_val.count < 2
      { type: :or, value: new_val }
    end


    def sqlize!(ast, fields)
      ast.map! do |node|
        if node[:type] == :and || node[:type] == :or || node[:type] == :not
          normalize!(node[:value], fields)
          next node
        end
        if node[:type] == :colon || node[:type] == :compare
          clean_comparison!(node, fields) if node[:type] == :compare
          key = dealias_key(node[:value][0][:value], fields)
          node[:value][0][:value] = key.to_s
          unless fields[key.to_sym] || fields[key.to_s]
            str_values = "#{key}#{node[:nest_op]}#{node[:value][1][:value]}"
            node = { type: :str, value: str_values }
          end
        end
        if node[:type] == :str || node[:type] == :quote || node[:type] == :number
          node = split_general_fields(node, fields)
        end
        node
      end
    end

  end
end
