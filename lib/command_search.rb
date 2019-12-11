load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/sqlizer.rb')
load(__dir__ + '/command_search/normalizer.rb')
load(__dir__ + '/command_search/optimizer.rb')

load(__dir__ + '/command_search/backends/memory.rb')
load(__dir__ + '/command_search/backends/mongoer.rb')
load(__dir__ + '/command_search/backends/postgres.rb')

class Boolean; end

module CommandSearch
  module_function

  def build(type, query, options)
    aliases = options[:aliases] || {}
    fields = options[:fields] || {}
    aliased_query = Aliaser.alias(query, aliases)
    ast = Lexer.lex(aliased_query)
    Parser.parse!(ast)
    Optimizer.optimize!(ast)
    if type == :postgres
      Normalizer.normalize!(ast, fields, false)
      return Postgres.build_query(ast)
    end
    Normalizer.normalize!(ast, fields)
    return Mongoer.build_query(ast) if type == :mongo
    ast
  end

  def search(source, query, options)
    if source.respond_to?(:mongo_client) && source.queryable
      ast = CommandSearch.build(:mongo, query, options)
      return source.where(ast)
    end
    ast = CommandSearch.build(:other, query, options)
    source.select { |x| CommandSearch::Memory.check(x, ast) }
  end
end
