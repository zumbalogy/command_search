class Mongoer
  class << self
    # sample input AST
    # ---- 'name3 desc:desk2' -------
    # [{:type=>:str, :value=>"name3"},
    #  {:type=>:nest,
    #   :nest_type=>:colon,
    #   :nest_op=>":",
    #   :value=>[{:type=>:str, :value=>"desc"}, {:type=>:str, :value=>"desk2"}]}]

    #     search('name3 desc:desk2') =>
    #      {'$and' => [
    #         { '$or' => [
    #           { 'title' => /name3/mi },
    #           { 'description' => /name3/mi },
    #           { 'tags' => /name3/mi }]},
    #         { 'description' => /desk2/mi }]}

    def build_search(str, fields)
      fields = [fields] unless fields.is_a?(Array)
      forms = fields.map { |f| { f => /#{str}/mi } }
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def build_searches(ast, fields, command_types)
      ast.flat_map do |x|
        if [:paren, :pipe, :minus].include?(x[:nest_type])
          x[:value] = build_searches(x[:value], fields, command_types)
        elsif x[:nest_type] == :colon
          # aliasing will be done before ast gets to mongoer.rb
          # TODO: dispatch on field type
          x = build_search(x[:value].first[:value], x[:value].last[:value])
        elsif x[:nest_type] == :compare
          # TODO: flesh this out
          x
        elsif x[:type] != :nest
          x = build_search(x[:value], fields)
        end
        x
      end
    end

    def build_tree(ast)
      ast.flat_map do |x|
        next x unless x[:nest_type]
        mongo_types = { paren: '$and', pipe: '$or', minus: '$not' }
        key = mongo_types[x[:nest_type]]
        { key => build_tree(x[:value]) }
      end
    end

    def collapse_ors(ast)
      ast.flat_map do |x|
        ['$and', '$or', '$not'].map do |key|
          next unless x[key]
          x[key] = collapse_ors(x[key])
        end
        next x unless x['$or']
        val = x['$or'].flat_map { |kid| kid['$or'] || kid }
        { '$or' => val }
      end
    end

    def build_query(ast, fields, command_types = {})
      # Numbers are searched as strings unless part of a compare/command
      out = ast
      out = build_searches(out, fields, command_types)
      out = build_tree(out)
      out = collapse_ors(out)
      out = out.first if out.count == 1
      out = { '$and' => out } if out.count > 1
      out
    end
  end
end
