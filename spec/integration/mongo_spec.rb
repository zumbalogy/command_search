load(__dir__ + '/../spec_helper.rb')
require('mongoid')

Mongoid.load!(__dir__ + '/mongoid.yml', :test)

class Hat
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
    Mongoid.purge!
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
    Hat.search('').selector.should == {}
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

  it 'should be able to search for a boolean' do
    Hat.create(title: 'foo', starred: true)
    Hat.create(title: 'bar', starred: true)
    Hat.create(title: 'bar 2', starred: false)
    Hat.search('starred:true').count.should == 2
    Hat.search('starred:false').count.should == 1
  end

  it 'should check for existance if passed a boolean for a string field' do
    Hat.create(title: 'foo', child_id: 'foo')
    Hat.create(title: 'batz', child_id: 'bar')
    Hat.search('child_id:true').count.should == 2
  end

  it 'should be able to find things from the description' do
    Hat.search('desk').selector.should == {
      '$or' => [
        { 'title' => /desk/i },
        { 'description' => /desk/i },
        { 'tags' => /desk/i }
      ]
    }
    Hat.search('desk').count.should == 4
    Hat.search('desk2').count.should == 1
    Hat.search('desk2 2').count.should == 1
  end

  it 'should be able to find things from the tags' do
    Hat.search('tags1').count.should == 1
    Hat.search('tags').count.should == 2
    Hat.search('multi tag').count.should == 1
    Hat.search('multi tag').selector.should == {
      '$and' => [
        { '$or' => [{ 'title' => /multi/i }, { 'description' => /multi/i }, { 'tags' => /multi/i }] },
        { '$or' => [{ 'title' => /tag/i }, { 'description' => /tag/i }, { 'tags' => /tag/i }] }
      ]
    }
    Hat.search("'quoted tag'").count.should == 1
    Hat.search("'quoted tag'").selector.should == {
      '$or' => [
        { 'title' => /\bquoted\ tag\b/ },
        { 'description' => /\bquoted\ tag\b/ },
        { 'tags' => /\bquoted\ tag\b/ }
      ]
    }
  end

  it 'should be able to find things from the title' do
    Hat.search('name1').count.should == 1
    Hat.search('name').count.should == 6
    Hat.search('same_name').count.should == 2
  end

  it 'should not be case sensitive' do
    Hat.search('name1').count.should == 1
    Hat.search('Name1').count.should == 1
    Hat.search('name').count.should == 6
    Hat.search('NAME').count.should == 6
    Hat.search('same_name').count.should == 2
    Hat.search('samE_NaMe').count.should == 2
  end

  it 'should be able to do case sensitive searches' do
    Hat.create(title: 'fQQ')
    Hat.search('title:fqq').count.should == 1
    Hat.search('title:fQQ').count.should == 1
    Hat.search('title:"fQQ"').count.should == 1
    Hat.search('title:"fqq"').count.should == 0
  end

  it 'should be able to find things across fields' do
    Hat.search('name3 tags1').count.should == 1
    Hat.search('name2 desk1').count.should == 1
    Hat.search('name2 desk2').count.should == 0
    Hat.search('desk3 tags2').count.should == 1
    Hat.search('desk0 tags2').count.should == 0
    Hat.search('desk3 tags3').count.should == 0
    Hat.search('desk3 tags2 name4').count.should == 1
  end

  it 'should be able to find things with new lines' do
    Hat.search('new line').count.should == 1
    Hat.search('desk new line').count.should == 1
  end

  it 'should be able to find things whatever the order of the searches' do
    Hat.search('new desk line').count.should == 1
    Hat.search('line new desk').count.should == 1
    Hat.search('   line    new    desk   ').count.should == 1
    Hat.search('desk3 tags2 name4').count.should == 1
    Hat.search('tags2 desk3 tags2 name4 tags2').count.should == 1
  end

  it 'should be able to find things that are quotes' do
    Hat.search("'quoted tag'").count.should == 1
    Hat.search("multi 'quoted tag'").count.should == 1
    Hat.search("multi 'quoted tag'").selector.should == {
      '$and' => [
        { '$or' => [{ 'title' => /multi/i }, { 'description' => /multi/i }, { 'tags' => /multi/i }] },
        { '$or' => [
            { 'title' => /\bquoted\ tag\b/ },
            { 'description' => /\bquoted\ tag\b/ },
            { 'tags' => /\bquoted\ tag\b/ }
          ] }
      ]
    }
  end

  it 'should be able to find things with commands' do
    Hat.search('title:name1').count.should == 1
    Hat.search('title:name1').selector.should == { 'title' => /name1/i }
    Hat.search('title:name500').count.should == 0
    Hat.search('feathers:5').count.should == 1
    Hat.search('cost:0').count.should == 1
    Hat.search('cost:0.0').count.should == 1
    Hat.search('cost:-0.0').count.should == 1
    Hat.search('cost:-0').count.should == 1
  end

  it 'should handle numeric existance checks' do
    Hat.search('feathers:true').count.should == 3
    Hat.search('feathers:false').count.should == 6
  end

  # it 'should handle undefined commands' do
  #   Hat.search('nam:name1').count.should == 0
  #   Hat.search('nam:name1').selector.should == { '$or' => [
  #                                                  { 'title' => /nam:foo/i },
  #                                                  { 'description' => /nam:foo/i },
  #                                                  { 'tags' => /nam:foo/i }] }
  # end

  it 'should be able to find things with aliased commands' do
    Hat.search('tags:tags1').count.should == 1
    Hat.search('tag:tags1').count.should == 1
    Hat.search('tag:tags1').selector.should == { 'tags' => /tags1/i }
  end

  it 'should be able to find things with quoted commands' do
    Hat.search("tag:'quoted tag'").count.should == 1
    Hat.search("tags:'quoted tag'").count.should == 1
  end

  it 'should be able to find things with multiple commands' do
    Hat.search('tags:tags2 title:name4').count.should == 1
    Hat.search('tags:tags2 title:name4').selector.should == {
      '$and' => [{ 'tags' => /tags2/i }, { 'title' => /name4/i }]
    }
  end

  it 'should be able to find things with commands and searches' do
    Hat.search('tags:tags1 name3').count.should == 1
    Hat.search('name3 desc:desk2').count.should == 1
    Hat.search('name3 desc:desk2').selector.should == {
      '$and' => [
        { '$or' => [
          { 'title' => /name3/i },
          { 'description' => /name3/i },
          { 'tags' => /name3/i }
        ] },
        { 'description' => /desk2/i }
      ]
    }
  end

  it 'should be able to to multiple quoted and aliased commands with multiple searches' do
    Hat.search('tag:tags1 title:name3 name desk').count.should == 1
    Hat.search('tag:tags1 title:name3 name desk').selector.should == {
      '$and' => [
        { 'tags' => /tags1/i },
        { 'title' => /name3/i },
        { '$or' =>
          [{ 'title' => /name/i }, { 'description' => /name/i }, { 'tags' => /name/i }]
        },
        { '$or' =>
          [{ 'title' => /desk/i }, { 'description' => /desk/i }, { 'tags' => /desk/i }]
        }
      ]
    }
  end

  it 'should be chainable with other selectors' do
    Hat.search('desc:desk1 2').where(title: /name2/).count.should == 1
    Hat.where(title: /name3/).search('desk2').where(tags: /tags1/).count.should == 1
  end

  it 'should handle quoted apostrophes' do
    Hat.search("\"someone's iHat\"").count.should == 1
    Hat.search("\"someone's iHat\"").selector.should == {"$or"=>[
                                                           {"title"=>/\bsomeone's\ iHat\b/},
                                                           {"description"=>/\bsomeone's\ iHat\b/},
                                                           {"tags"=>/\bsomeone's\ iHat\b/}]}
    Hat.search("title:\"someone's iHat\"").count.should == 1
    Hat.search("title:\"someone's iHat\"|name4").count.should == 2
  end

  it 'should handle OR searches' do
    Hat.search('name2|name3').count.should == 2
    Hat.search('name2|name3|name4').count.should == 3
    Hat.search('name2|name3|desk2').count.should == 2
    Hat.search('name2|name3|desk2|bad_search_sdfsdf').count.should == 2
  end

  it 'it should handle OR searches with other searches' do
    Hat.search('name2|name3 name2').count.should == 1
    Hat.search('name2|name3 name4').count.should == 0
    Hat.search('name4 name2|name3').count.should == 0
    Hat.search('desk3 name2|name3').count.should == 0
    Hat.search('desk2 name2|name3').count.should == 1
    Hat.search('desk2 name2|name3|desk2').count.should == 1
    Hat.search('desk2 name2|name3|desk3').count.should == 1
  end

  it 'it should handle multiple OR searches' do
    Hat.search('desk1|desk2 desk2|desk3').count.should == 1
    Hat.search('desk1|desk2 desk2||desk3').count.should == 1
    Hat.search('desk1|desk2 desk2|||desk3').count.should == 1
    Hat.search('desk1||desk2 desk2|||desk3').count.should == 1
    Hat.search('desk1|desk2 desk1|desk2').count.should == 2
    Hat.search('desk1|desk2|desk3 desk1|desk2').count.should == 2
    Hat.search('desk1|desk2|desk3 desk1|desk3|desk2').count.should == 3
    Hat.search('desk1||desk2|desk3 desk1|||desk3|desk2').count.should == 3
  end

  it 'it should handle multiple OR searches with command and non command searches' do
    Hat.search('tags:tags2|tags:tags1').count.should == 2
    Hat.search('tags:tags2|tags:tags1|tags:tags2').count.should == 2
    Hat.search('tags:tags2|tags:tags1|tags:tags9').count.should == 2
    Hat.search('tags:tags2|tags1').count.should == 2
    Hat.search('tags:tags2|tags1 tags1').count.should == 1
    Hat.search('tags:tags2|tags1 tags:tags1').count.should == 1
    Hat.search('tags:tags2|tags1 tags:tags2').count.should == 1
  end

  it 'should handle ORs with quotes' do
    Hat.search('desk1|desk2').count.should == 2
    Hat.search('desk1|"desk2"').count.should == 2
    Hat.search("desk1|'desk2'").count.should == 2
    Hat.search("'desk1'|'desk2'").count.should == 2
    Hat.search('"desk1"|"desk2"').count.should == 2
    Hat.search("'desk1'|desk2").count.should == 2
    Hat.search('"desk1"|desk2').count.should == 2
    Hat.search('"desk1"|"de|sk2"').count.should == 1
    Hat.search('"desk1"|desk2|"someone\'s iHat"').count.should == 3
    Hat.search('"desk1"|\'desk2\'|"someone\'s iHat"').count.should == 3
  end

  it 'it should handle negative searches' do
    check = 9
    Hat.search('').count.should == check
    (Hat.search('tags1').count + Hat.search('-tags1').count).should == check
    (Hat.search('tags:tags1').count + Hat.search('-tags:tags1').count).should == check
    (Hat.search('tags1 tags2').count + Hat.search('-tags1|-tags2').count).should == check
  end

  it 'it should handle multiple searches some negative' do
    Hat.search('-tags1 -tags2').count.should == 7
    Hat.search('tags1 -tags2').count.should == 1
    Hat.search('tags2 -tags2').count.should == 0
    Hat.search('tags1 -tags:tags2').count.should == 1
    Hat.search('tags:tags1 -tags2').count.should == 1
    Hat.search('tags:tags1 -tags:tags2').count.should == 1
  end

  it 'should handle comparisons' do
    Hat.search('0<feathers').count.should == 3
    Hat.search('feathers>0').count.should == 3
    Hat.search('feathers>2').count.should == 2
    Hat.search('feathers>5').count.should == 1
    Hat.search('feathers>8').count.should == 0
    Hat.search('feathers>=8').count.should == 1
    Hat.search('feathers<8').count.should == 2
    Hat.search('feathers<=5').count.should == 2
    Hat.search('feathers<cost').count.should == 1
    Hat.search('feathers>cost').count.should == 2
    Hat.search('cost>cost').count.should == 0
    Hat.search('cost<=cost').count.should == Hat.count
  end

  it 'should handle chained comparisons' do
    Hat.search('100>feathers>0').count.should == 3
    Hat.search('0<feathers>2').count.should == 2
    Hat.search('0<feathers<cost').count.should == 1
    Hat.search('feathers>=cost>0').count.should == 1
    Hat.search('feathers>=cost>=0').count.should == 2
    Hat.search('-5<feathers>=cost>=0').count.should == 2
    Hat.search('0<feathers<cost<200').count.should == 1
  end

  it 'should handle comparisons with dates' do
    # fav_date: fav_date: 1.week.ago, 2.months.ago, fav_date: 1.year.ago
    Hat.search('fav_date<=1_day_ago').count.should == 3
    Hat.search('fav_date<=15_days_ago').count.should == 2
    Hat.search('fav_date<3_months_ago').count.should == 1
    Hat.search('3_months_ago>fav_date').count.should == 1
    Hat.search('fav_date<2_years_ago').count.should == 0
    Hat.search('2_years_ago>fav_date').count.should == 0
    Hat.search('2_years_ago<fav_date').count.should == 3
  end

  it 'should handle negative comparisons and ORs put together. commands too' do
    # fav_date: fav_date: 1.week.ago, 2.months.ago, fav_date: 1.year.ago
    Hat.search('fav_date<2_years_ago').count.should == 0
    Hat.search('fav_date>2_years_ago').count.should == 3
    Hat.search('-fav_date>2_years_ago').count.should == 6
    Hat.search('-fav_date<2_years_ago').count.should == 9
    Hat.search('fav_date<1/20/1803').count.should == 0
    Hat.search('-fav_date<1/20/1803').count.should == 9
    Hat.search('fav_date<3_months_ago').count.should == 1
    Hat.search('fav_date>3_months_ago').count.should == 2
    Hat.search('-fav_date<3_months_ago').count.should == 8
    Hat.search('-fav_date<3-months-ago').count.should == 8
    Hat.search('-fav_date>3-months-ago').count.should == 7
    Hat.search('-fav_date<=1_day_ago').count.should == 6
    Hat.search('-fav_date<=1.day.ago').count.should == 6
    Hat.search('-fav_date<=1_day_ago|fav_date<=1_day_ago').count.should == 9
    Hat.search('-fav_date<=1_day_ago|desk1').count.should == 6
    Hat.search('-fav_date<=1_day_ago|-desk1').count.should == 9
  end

  it 'should handle nesting via parentheses' do
    Hat.search('-(-desk1)').count.should == 1
    Hat.search('(desk1 name2) | desk3').count.should == 2
    Hat.search('(desk1 name2) | desk3').count.should == 2
    Hat.create(title: 'a9 b9')
    Hat.create(title: 'b9 c9')
    Hat.create(title: 'c9 d9')
    Hat.search('(a9 b9) | (c9|d9)').count.should == 3
    Hat.search('(a9 b9) | (c9 d9)').count.should == 2
    Hat.search('(a9 b9) (c9 d9)').count.should == 0
  end

  it 'should handle quesiton marks without error' do
    Hat.search('?').count.should == 0
    Hat.search('(?)').count.should == 0
    Hat.search('(redgreenblue01?)').count.should == 0
  end

  it 'should be sortable via the alias' do
    Hat.create(title: 'aa', description: 'aa')
    Hat.create(title: 'zz', description: 'zz')
    sorted_titles = [
      nil,
      nil,
      'aa',
      'name name1 1',
      'name name2 2',
      'name name3 3',
      'name name4 4',
      'same_name',
      'same_name',
      'someone\'s iHat',
      'zz'
    ]
    sorted_desc = [
      nil,
      nil,
      nil,
      nil,
      nil,
      'aa',
      'desk desk1 1',
      'desk desk2 2',
      'desk desk3 3',
      "desk new \n line",
      'zz'
    ]
    Hat.search('sort:title').map(&:title).should == sorted_titles
    Hat.search('sort:bad_key_that_is_unsearchable').map(&:title).should_not == sorted_titles
    Hat.search('').map(&:title).should_not == sorted_titles
    Hat.search('sort:description').map(&:description).should == sorted_desc
    Hat.search('sort:sdfluho').map(&:description).should_not == sorted_desc
    Hat.search('').map(&:description).should_not == sorted_desc
  end

  it 'should handle different time data types' do
    class Bat1; include Mongoid::Document; field :fav_date, type: Time; end
    class Bat2; include Mongoid::Document; field :fav_date, type: Date; end
    class Bat3; include Mongoid::Document; field :fav_date, type: DateTime; end
    class Bat4; include Mongoid::Document; field :fav_date, type: DateTime; end

    def make_bats(fav_date)
      Bat1.create(fav_date: fav_date)
      Bat2.create(fav_date: fav_date)
      Bat3.create(fav_date: fav_date)
      Bat4.create(fav_date: fav_date)
    end

    def search_bats(query, total)
      [Bat1, Bat2, Bat3, Bat4].each do |klass|
        CommandSearch.search(klass, query, { command_fields: { fav_date: DateTime } }).count.should == total
        CommandSearch.search(klass, query, { command_fields: { fav_date: Date } }).count.should == total
        CommandSearch.search(klass, query, { command_fields: { fav_date: Time } }).count.should == total
      end
    end

    make_bats(Date.new(1000))
    make_bats(DateTime.now)
    make_bats(Time.now)
    make_bats(Time.new(1991))
    make_bats(Time.new(1995))
    make_bats(Time.new(1995, 1, 1))
    make_bats(Time.new(1995, 5, 5))
    make_bats(Time.new(1995, 12, 12))

    search_bats('fav_date:"1993"',       0)
    search_bats('fav_date:"1994"',       0)
    search_bats('fav_date:"1995"',       4)
    search_bats('fav_date:"1996"',       0)
    search_bats('fav_date:1000',         1)
    search_bats('fav_date:1991',         1)
    search_bats('fav_date<=1990',        1)
    search_bats('fav_date:"1991/01/01"', 1)
    search_bats('fav_date:"1991-01-01"', 1)
    search_bats('fav_date:1991-01-01',   1)
    search_bats('fav_date<=1991',        2)
    search_bats('fav_date<2010',         6)
    search_bats('fav_date>1990',         7)
    search_bats('fav_date<1990',         1)
    search_bats('fav_date<=1995',        6) # command_search looks at the first of the year for this.
    search_bats('fav_date<=1995-5-5',    5)
    search_bats('fav_date<1990-01-01',   1)
  end

  it 'should handle NOTs with commands with numbers' do
    Hat.search('feathers:0').count.should == 0
    Hat.search('-feathers:0').count.should == 9
    Hat.search('-feathers:100').count.should == 9
    Hat.search('-feathers:8').count.should == 8
    Hat.search('-feathers>7').count.should == 8
  end

  it 'should handle NOTs with ORs' do
    Hat.create(title: 'penguin', description: 'panda')
    Hat.create(description: 'panda')
    Hat.create(title: 'penguin')
    Hat.search('-panda').count.should == Hat.count - 2
    Hat.search('-(penguin panda)').count.should == Hat.count - 1
    Hat.search('-(penguin|panda)').count.should == Hat.count - 3
    Hat.search('-(penguin panda) panda').count.should == 1
    Hat.search('-(penguin panda) penguin').count.should == 1
    Hat.search('-(penguin panda) penguin panda').count.should == 0
    Hat.search('-(penguin -panda) panda').count.should == 2
    Hat.search('-(-penguin panda) panda').count.should == 1
  end

  it 'should handle wacky things' do
    Hat.search('-(zzz)|"b"').count.should == 9
    Hat.create(description: '')
    Hat.search('description:""').count.should == 1
    Hat.create(description: '')
    Hat.search('description:""').count.should == 2
  end

  # it 'should error gracefully' do
  #   lopsided parens
  #   Hat.search('(-sdf:sdfdf>sd\'s":f-').count.should == 0
  #   Hat.search('""sdfdsfhellosdf|dsfsdf::>>><><').count.should == 0
  # end

  # it 'should handle searching ones that are not specified and also wierd hash ones' do
  #   Hat.search('custom_s:penn').count.should == 1
  #   Hat.search('penn').count.should == 0
  #   Hat.search('custom_s:"penn station"').count.should == 1
  #   Hat.search('custom_h.id:foo').count.should == 1
  #   Hat.search('foo').count.should == 0
  #   Hat.search('id:foo').count.should == 0
  #   Hat.search('custom_h:foo').count.should == 0
  #   Hat.search('custom_h_id:foo').count.should == 0
  #   Hat.search('custom_h.id:bar').count.should == 0
  # end

end
