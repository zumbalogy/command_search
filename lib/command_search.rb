load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/command_dealiaser.rb')
load(__dir__ + '/command_search/optimizer.rb')
load(__dir__ + '/command_search/backends/memory.rb')
load(__dir__ + '/command_search/backends/mongoer.rb')
# load(__dir__ + '/command_search/backends/active_record_postgres.rb')
load(__dir__ + '/command_search/backends/postgres.rb')

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

    # TODO: make this dispatch poperly for mongo or psql or mysql
    if source.respond_to?(:ancestors) && source.ancestors.any? { |x| x.to_s == 'ActiveRecord::Base' }
      postgres_query = ActiveRecordPostgres.search(source, opted, fields, command_fields)
      # return postgres_query
      return source.where(postgres_query)
      # return source.find_by_sql("select * from #{source.table_name}") if postgres_query == ''
      # return source.find_by_sql("select * from #{source.table_name} where (#{postgres_query})")
    end

    selector = Memory.build_query(opted, fields, command_fields)
    source.select(&selector)
  end
end
