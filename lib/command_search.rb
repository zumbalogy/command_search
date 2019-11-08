load(__dir__ + '/command_search/aliaser.rb')
load(__dir__ + '/command_search/lexer.rb')
load(__dir__ + '/command_search/parser.rb')
load(__dir__ + '/command_search/normalizer.rb')
load(__dir__ + '/command_search/optimizer.rb')

load(__dir__ + '/command_search/backends/memory.rb')
load(__dir__ + '/command_search/backends/mongoer.rb')

class Boolean; end

module CommandSearch
  module_function

  def search(source, query, options)
    aliases = options[:aliases] || {}
    fields = options[:fields] || {}

    aliased_query = Aliaser.alias(query, aliases)
    ast = Lexer.lex(aliased_query)

    Parser.parse!(ast)
    Optimizer.optimize!(ast)
    Normalizer.normalize!(ast, fields)

    if source.respond_to?(:mongo_client) && source.queryable
      mongo_query = Mongoer.build_query(ast)
      return source.where(mongo_query)
    end

    source.select { |x| Memory.check(x, ast) }
  end
end

=begin

options = {
  aliases: {
    'favorite' => 'starred:true',
    'classic' => '(starred:true fav_date<15_years_ago)'
    # /=/ => ':',
    # 'me' => -> () { current_user.name },
    # /\$\d+/ => -> (match) { "cost:#{match[1..-1]}" }
  },
  fields: {
    child_id: { type: Boolean },
    title: { type: String, general_search: true },
    name: :title,
    description: { type: String, general_search: true },
    desc: :description,
    starred: { type: Boolean },
    star: :starred,
    tags: { type: String, general_search: true },
    tag: :tags,
    feathers: { type: Numeric, allow_existence_boolean: true },
    cost: { type: Numeric },
    fav_date: { type: Time }
  }
}

      fields: [:title, :description, :tags],
      command_fields: {
        child_id: Boolean,
        title: String,
        name: :title,
        description: String,
        desc: :description,
        starred: Boolean,
        star: :starred,
        tags: String,
        tag: :tags,
        feathers: [Numeric, :allow_existence_boolean],
        cost: Numeric,
        fav_date: Time
      },




=end
