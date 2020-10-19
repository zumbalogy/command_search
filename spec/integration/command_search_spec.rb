load(__dir__ + '/integration_helper.rb')

class Owl
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

$ducks = [
  { title: 'name name1 1' },
  { title: 'name name2 2', description: 'desk desk1 1' },
  { title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1' },
  { title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2' },
  { description: "desk new \n line" },
  { tags: "multi tag, 'quoted tag'" },
  { title: 'same_name', feathers: 2, cost: 0, fav_date: '2.months.ago' },
  { title: 'same_name', feathers: 5, cost: 4, fav_date: '1.year.ago' },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: '1.week.ago' }
]

def setup_table(table_name, config)
  ActiveRecord::Base.establish_connection(config)
  ActiveRecord::Schema.define do
    create_table table_name, force: true do |t|
      t.string :title
      t.string :description
      t.string :state
      t.string :tags
      t.boolean :starred
      t.string :child_id
      t.integer :feathers
      t.integer :cost
      t.datetime :fav_date
    end
  end
  ActiveRecord::Base.remove_connection(config)
end

PG_CONFIG = YAML.load_file("#{__dir__}/../assets/postgres.yml")['test']
MYSQL_CONFIG = YAML.load_file("#{__dir__}/../assets/mysql.yml")['test']
SQLITE_CONFIG = YAML.load_file("#{__dir__}/../assets/sqlite.yml")['test']

class Hawk < ActiveRecord::Base
  establish_connection(PG_CONFIG)
end

class Crow < ActiveRecord::Base
  establish_connection(MYSQL_CONFIG)
end

class Swan < ActiveRecord::Base
  establish_connection(SQLITE_CONFIG)
  class << self
    undef :postgresql_connection
    undef :mysql2_connection
  end
end

class Crow < ActiveRecord::Base
  class << self
    undef :postgresql_connection
    undef :sqlite3_connection
  end
end

def search_all(query, options, expected)
  CommandSearch.search(Owl, query, options).count.should == expected
  CommandSearch.search(Crow, query, options).count.should == expected
  CommandSearch.search(Hawk, query, options).count.should == expected
  CommandSearch.search(Swan, query, options).count.should == expected
  CommandSearch.search($ducks, query, options).count.should == expected
end

describe CommandSearch do
  before(:all) do
    # setup_table(:hawks, PG_CONFIG)
    # setup_table(:crows, MYSQL_CONFIG)
    # setup_table(:swans, SQLITE_CONFIG)

    Mongoid.purge!
    Crow.delete_all
    Swan.delete_all
    Hawk.delete_all
    Owl.delete_all

    Owl.create(title: 'name name1 1')
    Owl.create(title: 'name name2 2', description: 'desk desk1 1')
    Owl.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Owl.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Owl.create(description: "desk new \n line")
    Owl.create(tags: "multi tag, 'quoted tag'")
    Owl.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
    Owl.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
    Owl.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)

    Crow.create(title: 'name name1 1')
    Crow.create(title: 'name name2 2', description: 'desk desk1 1')
    Crow.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Crow.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Crow.create(description: "desk new \n line")
    Crow.create(tags: "multi tag, 'quoted tag'")
    Crow.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
    Crow.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
    Crow.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)

    Hawk.create(title: 'name name1 1')
    Hawk.create(title: 'name name2 2', description: 'desk desk1 1')
    Hawk.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Hawk.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Hawk.create(description: "desk new \n line")
    Hawk.create(tags: "multi tag, 'quoted tag'")
    Hawk.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
    Hawk.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
    Hawk.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)

    Swan.create(title: 'name name1 1')
    Swan.create(title: 'name name2 2', description: 'desk desk1 1')
    Swan.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Swan.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Swan.create(description: "desk new \n line")
    Swan.create(tags: "multi tag, 'quoted tag'")
    Swan.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
    Swan.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
    Swan.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)
  end

  it 'should be able to determine in memory vs mongo searches' do
    options = {
      fields: {
        child_id: { type: Boolean, general_search: true },
        title: { type: String, general_search: true },
        tags: { type: String, general_search: true },
        name: :title
      }
    }
    search_all('name:3|tags2', options, 2)
    search_all('name:name4', options, 1)
    search_all('name:-name4', options, 0)
    search_all('badKey:foo', options, 0)
  end

  it 'should handle queries that use invalid keys' do
    options = {
      fields: {
        child_id: { type: Boolean, general_search: true },
        title: { type: String, general_search: true },
        tags: { type: String, general_search: true },
      }
    }
    search_all('name:3|tags2', options, 1)
  end

  it 'should be able to work without command fields' do
    general = { type: String, general_search: true }
    options = { fields: { :title => general, :description => general, :tags => general } }
    options2 = { fields: { 'title' => general, :description => general, :tags => general } }
    birds2 = [
      { title: 'bird:1' },
      { 'title' => 'title:2' }
    ]
    search_all('3|tags2', options, 2)
    CommandSearch.search(birds2, 'bird:1', options).count.should == 1
    CommandSearch.search(birds2, 'title:2', options).count.should == 1
    CommandSearch.search(birds2, 'bird:1', options2).count.should == 1
    CommandSearch.search(birds2, 'title:2', options2).count.should == 1
  end

  it 'should be able to work without general searches' do
    options = {
      fields: {
        child_id: { type: Boolean },
        title: { type: String },
        name: :title
      }
    }
    search_all('name:3', options, 1)
    search_all('3', options, 0)
    search_all('feathers>4', options, 0)
  end

  it 'should handle existence booleans' do
    options = {
      fields: {
        title: { type: String, allow_existence_boolean: true }
      }
    }
    search_all('title:3', options, 1)
    search_all('title:true', options, 7)
    search_all('title:false', options, 2)
  end

  it 'should be able to handle unbalanced compares' do
    options = { command_fields: { feathers: Numeric } }
    search_all('4<', options, 0)
    search_all('4>', options, 0)
    search_all('<4', options, 0)
    search_all('>4', options, 0)
    search_all('4<=', options, 0)
    search_all('4>=', options, 0)
    search_all('<=4', options, 0)
    search_all('>=4', options, 0)
    search_all('feathers>>', options, 0)
    search_all('=<feathers>>', options, 0)
  end

  it 'should be able to handle a field declared as Numeric or Interger' do
    def helper(query, total)
      options = { fields: { feathers: { type: Numeric } } }
      options2 = { fields: { feathers: { type: Integer } } }
      search_all(query, options, total)
      search_all(query, options2, total)
    end
    helper('feathers>0', 3)
    helper('feathers>0.0', 3)
    helper('feathers>0.1', 3)
    helper('feathers>4', 2)
    helper('feathers>4.0', 2)
    helper('feathers>4.2', 2)
  end

  it 'should handle wacky inputs' do
    options = {
      fields: {
        child_id: { type: Boolean },
        title: { type: String, general_search: true },
        description: { type: String, general_search: true },
        tags: { type: String, general_search: true },
        name: :title,
      }
    }
    search_all('|desk', options, 4)
    search_all('desk|', options, 4)
    search_all('|desk|', options, 4)
    search_all('|desk', options, 4)
    search_all('desk|', options, 4)
    search_all('|desk|', options, 4)
  end

  it 'should handle long command alias chains' do
    options = {
      fields: {
        child_id: { type: Boolean },
        title: { type: String, general_search: true },
        description: { type: String, general_search: true },
        tags: { type: String, general_search: true },
        name: :title,
        foo: :name,
        bar: :name,
        zzz: :bar
      }
    }
    search_all('zzz:3|tags2', options, 2)
  end

  it 'should handle alaises' do
    sort_type = nil
    options = {
      fields: {
        child_id: { type: Boolean },
        title: { type: String, general_search: true },
        description: { type: String, general_search: true },
        tags: { type: String, general_search: true },
        name: :title
      },
      aliases: {
        /\bsort:\S+\b/ => proc { |match|
          sort_type = match.sub('sort:', '')
          ''
        }
      }
    }
    results = CommandSearch.search(Owl, 'sort:title name', options)
    results = results.order_by(sort_type => :asc) if sort_type
    results.map { |x| x[sort_type] }.should == [
      'name name1 1',
      'name name2 2',
      'name name3 3',
      'name name4 4',
      'same_name',
      'same_name'
    ]
    results = CommandSearch.search(Crow, 'sort:title name', options)
    results = results.order(sort_type => :asc) if sort_type
    results.map { |x| x[sort_type] }.should == [
      'name name1 1',
      'name name2 2',
      'name name3 3',
      'name name4 4',
      'same_name',
      'same_name'
    ]
    results2 = CommandSearch.search($ducks, 'sort:title', options)
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

  it 'should not throw errors' do
    CommandSearch.search([{}], "Q)'(':{Mc&hO    T)r", { fields: { foo: { type: String } } })
    CommandSearch.search([{}], 'm3(_:;_[P4ZV<]w)t', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], " d<1-Tw?.�e\u007Fy<1.E4:e>cb]", { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '=4Ts2em(5sZ ]]&x<-', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '<|SOUv~Y74+Fm+Yva`64', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], "4:O0E%~Z<@?O]e'h@<'k^", { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '(-sdf:sdfdf>sd\'s":f-', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '""sdfdsfhellosdf|dsfsdf::>>><><', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '|(|', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '|(|', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '| |', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], '()<', { fields: { foo: { type: String } } })
    CommandSearch.search([{}], 'foo:""', { command_fields: { foo: String } })
  end

  it 'should not throw errors in the presence of "naughty strings"' do
    # https://github.com/minimaxir/big-list-of-naughty-strings
    require('json')
    file = File.read(__dir__ + '/../assets/blns.json')
    list = JSON.parse(file)
    check = true
    list.each do |query|
      begin
        list = [
          { foo: query },
          { bar: query }
        ]
        options = {
          fields: {
            foo: { type: String },
            bar: { type: Numeric, general_search: true }
          }
        }
        CommandSearch.search(list, query, options)
        CommandSearch.search(Owl, query, options)
        CommandSearch.search(Crow, query, options)
        CommandSearch.search($ducks, query, options)
      rescue
        check = false
      end
    end
    check.should == true
  end

  it 'should handle fuzzing' do
    check = true
    trials = 50
    # trials = 500
    trials = 1234 if ENV['CI']
    trials.times do |i|
      query = (0...24).map { (rand(130)).chr }.join
      begin
        list = [
          { foo: query },
          { bar: query }
        ]
        options = {
          fields: {
            foo: { type: String },
            bar: { type: Numeric, general_search: true }
          }
        }
        CommandSearch.search(list, query, options)
        CommandSearch.search(Owl, query, options)
        CommandSearch.search(Crow, query, options)
        CommandSearch.search($ducks, query, options)
      rescue
        puts query.inspect
        check = false
        break
      end
    end
    check.should == true
  end

  it 'should handle permutations' do
    check = true
    strs = ['a', 'b', 'yy', '!', '', ' ', '0', '7', '-', '.', ':', '|', '<', '>', '=', '(', ')', '"', "'"]
    # size = 3
    size = 2
    size = 4 if ENV['CI']
    strs.repeated_permutation(size).each do |perm|
      begin
        list = [
          { foo: perm.join() },
          { bar: 'abcdefg' },
          { baz: 34, abc: 'xyz' },
        ]
        options = {
          fields: {
            foo: { type: String },
            bar: { type: Numeric, general_search: true }
          }
        }
        query = perm.join()
        CommandSearch.search(list, query, options)
        CommandSearch.search(Owl, query, options)
        CommandSearch.search(Crow, query, options)
        CommandSearch.search($ducks, query, options)
      rescue
        print(perm.join(), '    ')
        check = false
      end
    end
    check.should == true
  end
end
