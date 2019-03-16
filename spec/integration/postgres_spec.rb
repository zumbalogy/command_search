load(__dir__ + '/../spec_helper.rb')
require('active_record')
require('pg')

db_config = YAML.load_file(__dir__ + '/postgres.yml')
ActiveRecord::Base.establish_connection(db_config['test'])

ActiveRecord::Schema.define do
  create_table :hats, force: true do |t|
    t.string :title
    t.string :description
    t.string :state
    t.string :tags
    t.boolean :starred
    t.string :child_id
    t.integer :feathers
    t.integer :cost
    t.time :fav_date
  end
end

module PG_Spec

  class Hat < ActiveRecord::Base
    def self.search(query)
      head_border = '(?<=^|\s|[|(-])'
      tail_border = '(?=$|\s|[|)])'
      sortable_field_names = ['title', 'description']
      sort_field = nil
      options = {
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
        aliases: {
          /#{head_border}sort:\S+#{tail_border}/ => proc { |match|
            match_sort = match.sub(/^sort:/, '')
            sort_field = match_sort if sortable_field_names.include?(match_sort)
            nil
          }
        }
      }
      results = CommandSearch.search(Hat, query, options)
      results = results.order_by(sort_field => :asc) if sort_field
      return results
    end
  end

  describe Hat do

    before do
      Hat.create(title: 'name name1 1')
      Hat.create(title: 'name name2 2', description: 'desk desk1 1')
      Hat.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
      Hat.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
      Hat.create(description: "desk new \n line")
      Hat.create(tags: "multi tag, 'quoted tag'")
      Hat.create(title: 'same_name', feathers: 2, cost: 0, fav_date: 2.months.ago)
      Hat.create(title: 'same_name', feathers: 5, cost: 4, fav_date: 1.year.ago)
      Hat.create(title: "someone's iHat", feathers: 8, cost: 100, fav_date: 1.week.ago)
    end


    it 'should be able to do an empty string query' do
      Hat.search('').count.should == 9
    end

    it 'should be able to do specific matches' do
      Hat.create(title: 'ann')
      Hat.create(title: 'anne')
      Hat.create(title: 'nne')
      Hat.create(title: 'nn')
      Hat.create(title: 'zz zyx')
      Hat.search('"ann"').count.should == 1
      Hat.search('"nn"').count.should == 1
      Hat.search('"nne"').count.should == 1
      Hat.search('"zz"').count.should == 1
    end

    it 'should only be case sensitive for quoted text' do
      Hat.create(title: 'italy')
      Hat.create(title: 'Italy')
      Hat.create(title: 'ITALY')
      Hat.search('italy').count.should == 3
      Hat.search('Italy').count.should == 3
      Hat.search('ITALY').count.should == 3
      Hat.search('"italy"').count.should == 1
      Hat.search('"Italy"').count.should == 1
      Hat.search('"ITALY"').count.should == 1
      Hat.search('title:italy').count.should == 3
      Hat.search('title:Italy').count.should == 3
      Hat.search('title:ITALY').count.should == 3
      Hat.search('title:"italy"').count.should == 1
      Hat.search('title:"Italy"').count.should == 1
      Hat.search('title:"ITALY"').count.should == 1
    end

    it 'should be able to handle special characters' do
      Hat.create(title: '+')
      Hat.create(title: 'a+')
      Hat.create(title: 'a++')
      Hat.create(title: '+a')
      Hat.create(title: '+a+')
      Hat.create(title: 'a+a')
      Hat.create(title: '.a+.')
      Hat.create(title: '(b+)')
      Hat.create(title: 'c?')
      Hat.create(title: 'x,y,z')
      Hat.search('title:+').count.should == 8
      Hat.search('+').count.should == 8
      Hat.search('title:+a').count.should == 3
      Hat.search('+a').count.should == 3
      Hat.search('title:a+').count.should == 5
      Hat.search('a+').count.should == 5
      Hat.search('title:"a+"').count.should == 2
      Hat.search('"a+"').count.should == 2
      Hat.search('title:"b+"').count.should == 1
      Hat.search('"b+"').count.should == 1
      Hat.search('title:"c"').count.should == 1
      Hat.search('"c"').count.should == 1
      Hat.search('title:"c?"').count.should == 1
      Hat.search('"c?"').count.should == 1

      Hat.search('"x"').count.should == 1
      Hat.search('y').count.should == 1
      Hat.search('"y"').count.should == 1
      Hat.search('"z"').count.should == 1
      Hat.search('title:y').count.should == 1
      Hat.search('title:"y"').count.should == 1
      Hat.search('title:"z"').count.should == 1
      Hat.search('title:"y,z"').count.should == 1
    end
  end
end
