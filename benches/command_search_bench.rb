require('benchmark')
require('mongoid')

load(__dir__ + '/../lib/command_search.rb')

Mongoid.load!(__dir__ + '/../spec/integration/mongoid.yml', :test)

class Bird
  include Mongoid::Document
  field :title,       type: String
  field :description, type: String
  field :state,       type: String
  field :tags,        type: String
  field :starred,     type: Boolean
  field :child_id,    type: String
  field :feathers,    type: Integer
  field :cost,        type: Integer
  field :fav_date,    type: Time
end

$birds = [
  { title: 'name name1 1' },
  { title: 'name name2 2', description: 'desk desk1 1' },
  { title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1' },
  { title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2' },
  { description: "desk new \n line" },
  { tags: "multi tag, 'quoted tag'" },
  { title: 'same_name', feathers: 2, cost: 0, fav_date: "2.months.ago" },
  { title: 'same_name', feathers: 5, cost: 4, fav_date: "1.year.ago" },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: "1.week.ago" }
]

Bird.destroy_all

1000.times do |i|
  Bird.create({ title: 'name ' + i.to_s, description: i.to_s, cost: rand, feathers: i })
end

1000.times do |i|
  $birds.push({ title: 'name ' + i.to_s, description: i.to_s, cost: rand, feathers: i })
end

$iterations = 100

Benchmark.bmbm() do |bm|
  $bm = bm

  def mem(query, options)
    title = "Mem: #{query.inspect} #{options.to_s.tr('=>', ' ')}"
    $bm.report(title) { $iterations.times { CommandSearch.search($birds, query, options).count } }
  end

  def mongo(query, options)
    title = "Mongo: #{query.inspect} #{options.to_s.tr('=>', ' ')}"
    $bm.report(title) { $iterations.times { CommandSearch.search(Bird, query, options).count } }
  end

  mem('', {})
  mem('', { fields: [] })
  mem('name', { })
  mem('name', { fields: [:title, :description, :tags] })
  mem('name', { command_fields: { has_child_id: Boolean, title: String, name: :title } })
  mem('title:name', { command_fields: { has_child_id: Boolean, title: String, name: :title } })

  mem('name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mem('title:name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mem('name title:name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mem('name title:name', {
    fields: [:title, :description, :tags, :foo, :bar, :baz, :a, :b, :c],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })

  mongo('', {})
  mongo('', { fields: [] })
  mongo('name', { })
  mongo('name', { fields: [:title, :description, :tags] })
  mongo('name', { command_fields: { has_child_id: Boolean, title: String, name: :title } })
  mongo('title:name', { command_fields: { has_child_id: Boolean, title: String, name: :title } })

  mongo('name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mongo('title:name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mongo('name title:name', {
    fields: [:title, :description, :tags],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
  mongo('name title:name', {
    fields: [:title, :description, :tags, :foo, :bar, :baz, :a, :b, :c],
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  })
end
