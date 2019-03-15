load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/command_dealiaser.rb')
load(__dir__ + '/command_search/optimizer.rb')
load(__dir__ + '/command_search/memory.rb')
load(__dir__ + '/command_search/mongoer.rb')
load(__dir__ + '/command_search/postgres.rb')

class Boolean; end

module CommandSearch
  module_function

  def search(source, query, options = {})
    aliases = options[:aliases] || {}
    fields = options[:fields] || []
    command_fields = options[:command_fields] || {}

    aliased_query = Aliaser.alias(query, aliases)
    tokens = Lexer.lex(aliased_query)
    parsed = Parser.parse!(tokens)
    dealiased = CommandDealiaser.dealias(parsed, command_fields)
    cleaned = CommandDealiaser.decompose_unaliasable(dealiased, command_fields)
    opted = Optimizer.optimize(cleaned)

    if source.respond_to?(:mongo_client) && source.queryable
      fields = [:__CommandSearch_mongo_fields_dummy_key__] if fields.empty?
      mongo_query = Mongoer.build_query(opted, fields, command_fields)
      return source.where(mongo_query)
    end

    if source.respond_to?(:ancestors) && source.ancestors.any? { |x| x.to_s == 'ActiveRecord::Base' }
      return Postgres.search(source, opted, fields, command_fields)
    end

    selector = Memory.build_query(opted, fields, command_fields)
    source.select(&selector)
  end
end
