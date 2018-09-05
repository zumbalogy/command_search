load(__dir__ + '/../spec_helper.rb')

require('mongoid')

Mongoid.load!(__dir__ + '/../../mongoid.yml', :test)

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

describe CommandSearch do

  before do
    Mongoid.purge!
    Bird.create(title: 'name name1 1')
    Bird.create(title: 'name name2 2', description: 'desk desk1 1')
    Bird.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Bird.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Bird.create(description: "desk new \n line")
    Bird.create(tags: "multi tag, 'quoted tag'")
    Bird.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
    Bird.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
    Bird.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)
  end

  it 'should be able to determine in memory vs mongo searches' do
    search_fields = [:title, :description, :tags]
    command_fields = {
      has_child_id: Boolean,
      title: String,
      name: :title
    }
    query = 'name:3|tags2'
    CommandSearch.search(Bird, query, search_fields, command_fields).count.should == 2
    CommandSearch.search($birds, query, search_fields, command_fields).count.should == 2
    CommandSearch.search(Bird, 'name:name4', search_fields, command_fields).count.should == 1
    CommandSearch.search($birds, 'name:name4', search_fields, command_fields).count.should == 1
    CommandSearch.search(Bird, 'badKey:foo', search_fields, command_fields).count.should == 0
    CommandSearch.search($birds, 'badKey:foo', search_fields, command_fields).count.should == 0
  end

  it 'should handle invalid keys' do
    search_fields = [:title, :description, :tags]
    command_fields = {
      has_child_id: Boolean,
      title: String
    }
    query = 'name:3|tags2'
    CommandSearch.search($birds, query, search_fields, command_fields).count.should == 1
    CommandSearch.search(Bird, query, search_fields, command_fields).count.should == 1
  end

  it 'should be able to work without command fields' do
    birds2 = [
      { title: 'bird:1' },
      { title: 'title:2' }
    ]
    search_fields = [:title, :description, :tags]
    query = '3|tags2'
    CommandSearch.search(Bird, query, search_fields).count.should == 2
    CommandSearch.search($birds, query, search_fields).count.should == 2
    CommandSearch.search(birds2, 'bird:1', search_fields).count.should == 1
    CommandSearch.search(birds2, 'title:2', search_fields).count.should == 1
  end

  it 'should be able to work without search fields' do
    command_fields = {
      has_child_id: Boolean,
      title: String,
      name: :title
    }
    CommandSearch.search(Bird, 'name:3', [], command_fields).count.should == 1
    CommandSearch.search($birds, 'name:3', [], command_fields).count.should == 1
    CommandSearch.search(Bird, '3', [], command_fields).count.should == 0
    CommandSearch.search($birds, '3', [], command_fields).count.should == 0
    CommandSearch.search($birds, 'feathers>4', [], command_fields).count.should == 0
    CommandSearch.search(Bird, 'feathers>4', [], command_fields).count.should == 0
  end

  it 'should handle wacky inputs' do
    search_fields = [:title, :description, :tags]
    command_fields = {
      has_child_id: Boolean,
      title: String,
      name: :title
    }
    CommandSearch.search($birds, '|desk', search_fields, command_fields).count.should == 4
    CommandSearch.search($birds, 'desk|', search_fields, command_fields).count.should == 4
    CommandSearch.search($birds, '|desk|', search_fields, command_fields).count.should == 4
    CommandSearch.search(Bird, '|desk', search_fields, command_fields).count.should == 4
    CommandSearch.search(Bird, 'desk|', search_fields, command_fields).count.should == 4
    CommandSearch.search(Bird, '|desk|', search_fields, command_fields).count.should == 4
  end

  it 'should handle long alias chains' do
    search_fields = [:title, :description, :tags]
    command_fields = {
      has_child_id: Boolean,
      title: String,
      name: :title,
      foo: :name,
      bar: :name,
      zzz: :bar
    }
    query = 'zzz:3|tags2'
    CommandSearch.search(Bird, query, search_fields, command_fields).count.should == 2
    CommandSearch.search($birds, query, search_fields, command_fields).count.should == 2
  end
end
