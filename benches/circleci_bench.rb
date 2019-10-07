require('benchmark')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.bmbm do |bm|
  bm.report do
    100000.times do
      input = '(price<=200 discount)|price<=99.99'
      fields = [:title, :description, :tags]
      command_fields = { has_child_id: Boolean, title: String, name: :title }
      aliased = CommandSearch::Aliaser.alias(input, { 'foo' => 'bar' })
      lexed = CommandSearch::Lexer.lex(aliased)
      parsed = CommandSearch::Parser.parse!(lexed)
      dealiased = CommandSearch::CommandDealiaser.dealias(parsed, command_fields)
      cleaned = CommandSearch::CommandDealiaser.decompose_unaliasable(dealiased, command_fields)
      opted = CommandSearch::Optimizer.optimize(cleaned)
      CommandSearch::Mongoer.build_query(opted, fields, command_fields)
    end
  end
end
