load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/normalizer.rb')
load(__dir__ + '/command_search/optimizer.rb')
load(__dir__ + '/command_search/preprocessor.rb')

# TODO: change these names
# load(__dir__ + '/command_search/backends/memory.rb')
# load(__dir__ + '/command_search/backends/mongoer.rb')
load(__dir__ + '/command_search/memory.rb')
load(__dir__ + '/command_search/mongoer.rb')

class Boolean; end

module CommandSearch
  module_function

  def search(source, query, options = {})
    aliases = options[:aliases] || {}
    fields = options[:fields] || []
    command_fields = options[:command_fields] || {}

    aliased_query = Aliaser.alias(query, aliases)
    ast = Lexer.lex(aliased_query)
    Parser.parse!(ast)
    Optimizer.optimize!(ast)
    command_fields = Normalizer.normalize!(ast, command_fields)

    if source.respond_to?(:mongo_client) && source.queryable
      fields = [:__CommandSearch_dummy_key__] if fields.empty?
      mongo_query = Mongoer.build_query(ast, fields, command_fields)
      return source.where(mongo_query)
    end

    source.select { |x| Memory.check(x, ast, fields, command_fields) }
  end
end
