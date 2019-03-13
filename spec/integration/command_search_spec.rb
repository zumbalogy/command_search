load(__dir__ + '/../spec_helper.rb')

require('mongoid')

Mongoid.load!(__dir__ + '/mongoid.yml', :test)

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
    options = {
      fields: [:title, :description, :tags],
      command_fields: {
        has_child_id: Boolean,
        title: String,
        name: :title
      }
    }
    query = 'name:3|tags2'
    CommandSearch.search(Bird, query, options).count.should == 2
    CommandSearch.search($birds, query, options).count.should == 2
    CommandSearch.search(Bird, 'name:name4', options).count.should == 1
    CommandSearch.search($birds, 'name:name4', options).count.should == 1
    CommandSearch.search(Bird, 'name:-name4', options).count.should == 0
    CommandSearch.search($birds, 'name:-name4', options).count.should == 0
    CommandSearch.search(Bird, 'badKey:foo', options).count.should == 0
    CommandSearch.search($birds, 'badKey:foo', options).count.should == 0
  end

  it 'should handle invalid keys' do
    options = {
      fields: [:title, :description, :tags],
      command_fields: {
        has_child_id: Boolean,
        title: String
      }
    }
    query = 'name:3|tags2'
    CommandSearch.search($birds, query, options).count.should == 1
    CommandSearch.search(Bird, query, options).count.should == 1
  end

  it 'should be able to work without command fields' do
    options = { fields: [:title, :description, :tags] }
    options2 = { fields: ['title', :description, :tags] }
    birds2 = [
      { title: 'bird:1' },
      { 'title' => 'title:2' }
    ]
    query = '3|tags2'
    CommandSearch.search(Bird, query, options).count.should == 2
    CommandSearch.search($birds, query, options).count.should == 2
    CommandSearch.search(birds2, 'bird:1', options).count.should == 1
    CommandSearch.search(birds2, 'title:2', options).count.should == 1
    CommandSearch.search(birds2, 'bird:1', options2).count.should == 1
    CommandSearch.search(birds2, 'title:2', options2).count.should == 1
  end

  it 'should be able to work without search fields' do
    options = {
      command_fields: {
        has_child_id: Boolean,
        title: String,
        name: :title
      }
    }
    CommandSearch.search(Bird, 'name:3', options).count.should == 1
    CommandSearch.search($birds, 'name:3', options).count.should == 1
    CommandSearch.search(Bird, '3', options).count.should == 0
    CommandSearch.search($birds, '3', options).count.should == 0
    CommandSearch.search($birds, 'feathers>4', options).count.should == 0
    CommandSearch.search(Bird, 'feathers>4', options).count.should == 0
  end

  it 'should handle existence booleans' do
    options = {
      command_fields: {
        title: [String, :allow_existence_boolean]
      }
    }
    CommandSearch.search(Bird, 'title:3', options).count.should == 1
    CommandSearch.search(Bird, 'title:true', options).count.should == 7
    CommandSearch.search(Bird, 'title:false', options).count.should == 2
    CommandSearch.search($birds, 'title:3', options).count.should == 1
    CommandSearch.search($birds, 'title:true', options).count.should == 7
    CommandSearch.search($birds, 'title:false', options).count.should == 2
  end

  it 'should be able to handle unbalanced compares' do
    options = { command_fields: { feathers: Numeric } }
    CommandSearch.search($birds, 'feathers>', options).count.should == 0
    CommandSearch.search($birds, '>4', options).count.should == 0
    CommandSearch.search($birds, '4<', options).count.should == 0
    CommandSearch.search($birds, '4>=', options).count.should == 0
    CommandSearch.search(Bird, 'feathers>', options).count.should == 0
    CommandSearch.search(Bird, '>4', options).count.should == 0
    CommandSearch.search(Bird, '4<', options).count.should == 0
    CommandSearch.search(Bird, '4>=', options).count.should == 0
    CommandSearch.search($birds, 'feathers>>', options).count.should == 0
    CommandSearch.search($birds, '=<feathers>>', options).count.should == 0
    CommandSearch.search(Bird, 'feathers>>', options).count.should == 0
    CommandSearch.search(Bird, '=<feathers>>', options).count.should == 0
  end

  it 'should be able to handle a field declared as Numeric or Interger' do
    options = { command_fields: { feathers: Numeric } }
    CommandSearch.search(Bird, 'feathers>0', options).count.should == 3
    CommandSearch.search(Bird, 'feathers>0.0', options).count.should == 3
    CommandSearch.search(Bird, 'feathers>0.1', options).count.should == 3
    CommandSearch.search(Bird, 'feathers>4', options).count.should == 2
    CommandSearch.search(Bird, 'feathers>4.0', options).count.should == 2
    CommandSearch.search(Bird, 'feathers>4.2', options).count.should == 2
    CommandSearch.search($birds, 'feathers>4', options).count.should == 2
    CommandSearch.search($birds, 'feathers>4.0', options).count.should == 2
    CommandSearch.search($birds, 'feathers>4.2', options).count.should == 2
    options2 = { command_fields: { feathers: Integer } }
    CommandSearch.search(Bird, 'feathers>0', options2).count.should == 3
    CommandSearch.search(Bird, 'feathers>0.0', options2).count.should == 3
    CommandSearch.search(Bird, 'feathers>0.1', options2).count.should == 3
    CommandSearch.search(Bird, 'feathers>4', options2).count.should == 2
    CommandSearch.search(Bird, 'feathers>4.0', options2).count.should == 2
    CommandSearch.search(Bird, 'feathers>4.2', options2).count.should == 2
    CommandSearch.search($birds, 'feathers>0', options2).count.should == 3
    CommandSearch.search($birds, 'feathers>0.0', options2).count.should == 3
    CommandSearch.search($birds, 'feathers>0.1', options2).count.should == 3
    CommandSearch.search($birds, 'feathers>4', options2).count.should == 2
    CommandSearch.search($birds, 'feathers>4.0', options2).count.should == 2
    CommandSearch.search($birds, 'feathers>4.2', options2).count.should == 2
  end

  it 'should handle wacky inputs' do
    options = {
      fields: [:title, :description, :tags],
      command_fields: {
        has_child_id: Boolean,
        title: String,
        name: :title
      }
    }
    CommandSearch.search($birds, '|desk', options).count.should == 4
    CommandSearch.search($birds,  'desk|', options).count.should == 4
    CommandSearch.search($birds, '|desk|', options).count.should == 4
    CommandSearch.search(Bird,   '|desk', options).count.should == 4
    CommandSearch.search(Bird,    'desk|', options).count.should == 4
    CommandSearch.search(Bird,   '|desk|', options).count.should == 4
  end

  it 'should handle long command alias chains' do
    options = {
      fields: [:title, :description, :tags],
      command_fields: {
        has_child_id: Boolean,
        title: String,
        name: :title,
        foo: :name,
        bar: :name,
        zzz: :bar
      }
    }
    query = 'zzz:3|tags2'
    CommandSearch.search(Bird, query, options).count.should == 2
    CommandSearch.search($birds, query, options).count.should == 2
  end

  it 'should handle alaises' do
    sort_type = nil
    options = {
      fields: [:title, :description, :tags],
      command_fields: {
        has_child_id: Boolean,
        title: String,
        name: :title
      },
      aliases: {
        /\bsort:\S+\b/ => proc { |match|
          sort_type = match.sub('sort:', '')
          ''
        }
      }
    }
    results = CommandSearch.search(Bird, 'sort:title name', options)
    results = results.order_by(sort_type => :asc) if sort_type
    results.map { |x| x[sort_type] }.should == [
      'name name1 1',
      'name name2 2',
      'name name3 3',
      'name name4 4',
      'same_name',
      'same_name'
    ]
    results2 = CommandSearch.search($birds, 'sort:title', options)
    results2 = results2.sort_by { |x| x[sort_type.to_sym] || '' } if sort_type
    results2.map { |x| x[sort_type.to_sym] }.should == [
      nil,
      nil,
      'name name1 1',
      'name name2 2',
      'name name3 3',
      'name name4 4',
      'same_name',
      'same_name',
      'someone\'s iHat'
    ]
  end
end
