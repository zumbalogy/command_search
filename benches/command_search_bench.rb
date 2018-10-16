require('benchmark')

load(__dir__ + '/../lib/command_search.rb')

iter = 1000

birds = [
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

Benchmark.bmbm() do |x|
  x.report('Overhead') { iter.times { nil } }
  x.report('Totally empty search') { iter.times { CommandSearch.search([], '', {}) } }
  x.report('Empty search query and fields') { iter.times { CommandSearch.search(birds, '', {}) } }
  x.report('Empty search query') { iter.times { CommandSearch.search(birds, '', {search_fields: []}) } }
  x.report('Empty search fields') { iter.times { CommandSearch.search(birds, 'name', {}) } }
  options = { fields: [:title, :description, :tags] }
  x.report('Search fields') { iter.times { CommandSearch.search(birds, 'name', options) } }
  options =options = {
    command_fields: { has_child_id: Boolean, title: String, name: :title }
  }
  x.report('Command fields') { iter.times { CommandSearch.search(birds, 'name', options) } }
end
