load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/command_dealiaser.rb')
load(__dir__ + '/command_search/optimizer.rb')
load(__dir__ + '/command_search/preprocessor.rb')

# TODO:
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
    foo = Lexer.lex(aliased_query)
    Parser.parse!(foo)
    CommandDealiaser.dealias(foo, command_fields)
    CommandDealiaser.decompose_unaliasable(foo, command_fields)
    CommandDealiaser.cast_all_types(foo, command_fields)
    cleaned_cmd_fields = CommandDealiaser.clean_command_fields(command_fields)
    Optimizer.optimize(foo)
    # Preprocessor.preprocess(foo, fields, cleaned_cmd_fields)

    if source.respond_to?(:mongo_client) && source.queryable
      fields = [:__CommandSearch_mongo_fields_dummy_key__] if fields.empty?
      mongo_query = Mongoer.build_query(foo, fields, cleaned_cmd_fields)
      return source.where(mongo_query)
    end

    source.select { |x| Memory.check(x, foo, fields, cleaned_cmd_fields) }
  end
end
