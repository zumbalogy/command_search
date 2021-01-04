Gem::Specification.new do |s|
  s.name        = 'command_search'
  s.version     = '0.12.1'

  s.summary     = 'Let users query collections with ease.'
  s.description = 'Build powerful and friendly search APIs for users.'
  s.authors     = ['zumbalogy']
  s.files       = `git ls-files lib`.split("\n")
  s.homepage    = 'https://github.com/zumbalogy/command_search'
  s.license     = 'Unlicense'

  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'chronic', '~> 0.10.2'
end
