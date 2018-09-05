load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/dealiaser.rb')
load(__dir__ + '/command_search/optimizer.rb')
load(__dir__ + '/command_search/mongoer.rb')
load(__dir__ + '/command_search/memory.rb')

class Boolean; end

module CommandSearch
  module_function

  def search(source, query, fields, command_fields = {})
    tokens = Lexer.lex(query)
    parsed = Parser.parse(tokens)
    dealiased = Dealiaser.dealias(parsed, command_fields)
    cleaned = Dealiaser.decompose_unaliasable(dealiased, command_fields)
    opted = Optimizer.optimize(cleaned)
    if source.respond_to?(:mongo_client) && source.queryable
      fields = [:__CommandSearch_mongo_fields_dummy_key__] if fields.empty?
      mongo_query = Mongoer.build_query(opted, fields, command_fields)
      return source.where(mongo_query)
    end
    selector = Memory.build_query(opted, fields, command_fields)
    source.select(&selector)
  end
end
