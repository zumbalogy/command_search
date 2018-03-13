load(__dir__ + '/../spec_helper.rb')
require('mongoid')

Mongoid.load!(__dir__ + '/../../mongoid.yml', :test)

class Hat
  include Mongoid::Document
  field :title,       type: String
  field :description, type: String
  field :state,       type: String
  field :tags,        type: String
  field :starred,     type: Boolean
  field :child_id,    type: String
  field :feathers,    type: Integer
  field :fav_date,    type: Time

  def self.search(query)
    search_fields = [:title, :description, :tags]
    command_fields = {
      child_id: Boolean,
      title: String,
      name: :title,
      description: String,
      desc: :description,
      starred: Boolean,
      star: :starred,
      tags: String,
      tag: :tags,
      feathers: Numeric,
      fav_date: Time
    }
    tokens = Lexer.lex(query)
    parsed = Parser.parse(tokens)
    opted = Optimizer.optimize(parsed)
    dealiased = Dealiaser.dealias(opted, command_fields)
    mongo_query = Mongoer.build_query(dealiased, search_fields, command_fields)
    Hat.where(mongo_query)
  end
end

describe Hat do # TODO: describe real class
  before do
    Mongoid.purge!
    Hat.create(title: 'name name1 1')
    Hat.create(title: 'name name2 2', description: 'desk desk1 1')
    Hat.create(title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1')
    Hat.create(title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2')
    Hat.create(description: "desk new \n line")
    Hat.create(tags: "multi tag, 'quoted tag'")
    Hat.create(title: 'same_name', feathers: 2, fav_date: 2.months.ago)
    Hat.create(title: 'same_name', feathers: 5, fav_date: 1.year.ago)
    Hat.create(title: "someone's iHat", feathers: 8, fav_date: 1.week.ago)
  end

  it 'should be able to do an empty string query' do
    Hat.search('').selector.should == {}
    Hat.search('').count.should == 9
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
        { 'title' => /desk/mi },
        { 'description' => /desk/mi },
        { 'tags' => /desk/mi }
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
        { '$or' => [{ 'title' => /multi/mi }, { 'description' => /multi/mi }, { 'tags' => /multi/mi }] },
        { '$or' => [{ 'title' => /tag/mi }, { 'description' => /tag/mi }, { 'tags' => /tag/mi }] }
      ]
    }
    Hat.search("'quoted tag'").count.should == 1
    Hat.search("'quoted tag'").selector.should == {
      '$or' => [
        { 'title' => /quoted\ tag/ },
        { 'description' => /quoted\ tag/ },
        { 'tags' => /quoted\ tag/ }
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
        { '$or' => [{ 'title' => /multi/mi }, { 'description' => /multi/mi }, { 'tags' => /multi/mi }] },
        { '$or' => [
            { 'title' => /quoted\ tag/ },
            { 'description' => /quoted\ tag/ },
            { 'tags' => /quoted\ tag/ }
          ] }
      ]
    }
  end

  it 'should be able to find things with commands' do
    Hat.search('title:name1').count.should == 1
    Hat.search('title:name1').selector.should == { 'title' => /name1/mi }
    Hat.search('title:name500').count.should == 0
  end

  # it 'should handle undefined commands' do
  #   Hat.search('nam:name1').count.should == 0
  #   Hat.search('nam:name1').selector.should == { '$or' => [
  #                                                  { 'title' => /nam:foo/mi },
  #                                                  { 'description' => /nam:foo/mi },
  #                                                  { 'tags' => /nam:foo/mi }] }
  # end

  it 'should be able to find things with aliased commands' do
    Hat.search('tags:tags1').count.should == 1
    Hat.search('tag:tags1').count.should == 1
    Hat.search('tag:tags1').selector.should == { 'tags' => /tags1/mi }
  end

  it 'should be able to find things with quoted commands' do
    Hat.search("tag:'quoted tag'").count.should == 1
    Hat.search("tags:'quoted tag'").count.should == 1
    Hat.search("tags:'quoted tag'").selector.should == { 'tags' => /quoted\ tag/ }
  end

  it 'should be able to find things with multiple commands' do
    Hat.search('tags:tags2 title:name4').count.should == 1
    Hat.search('tags:tags2 title:name4').selector.should == {
      '$and' => [{ 'tags' => /tags2/mi }, { 'title' => /name4/mi }]
    }
  end

  it 'should be able to find things with commands and searches' do
    Hat.search('tags:tags1 name3').count.should == 1
    Hat.search('name3 desc:desk2').count.should == 1
    Hat.search('name3 desc:desk2').selector.should == {
      '$and' => [
        { '$or' => [
          { 'title' => /name3/mi },
          { 'description' => /name3/mi },
          { 'tags' => /name3/mi }
        ] },
        { 'description' => /desk2/mi }
      ]
    }
  end

  it 'should be able to to multiple quoted and aliased commands with multiple searches' do
    Hat.search('tag:tags1 title:name3 name desk').count.should == 1
    Hat.search('tag:tags1 title:name3 name desk').selector.should == {
      '$and' => [
        { 'tags' => /tags1/mi },
        { 'title' => /name3/mi },
        { '$or' =>
          [{ 'title' => /name/mi }, { 'description' => /name/mi }, { 'tags' => /name/mi }]
        },
        { '$or' =>
          [{ 'title' => /desk/mi }, { 'description' => /desk/mi }, { 'tags' => /desk/mi }]
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
                                                           {"title"=>/someone's\ iHat/},
                                                           {"description"=>/someone's\ iHat/},
                                                           {"tags"=>/someone's\ iHat/}]}
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
    Hat.search('desk1|desk2 desk1|desk2').count.should == 2
    Hat.search('desk1|desk2|desk3 desk1|desk2').count.should == 2
    Hat.search('desk1|desk2|desk3 desk1|desk3|desk2').count.should == 3
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
    # q.alias_fields[/^string$/i] = 'desk2'
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

  # it 'should handle regex aliases' do
  #   # q.alias_fields[/^string$/i] = 'desk2'
  #   Hat.search('desk1|string').count.should == 2
  #   Hat.search('desk1|"string"').count.should == 2
  #   Hat.search("desk1|'string'").count.should == 2
  #   Hat.search("'desk1'|'string'").count.should == 2
  #   Hat.search('"desk1"|"string"').count.should == 2
  #   Hat.search("'desk1'|string").count.should == 2
  #   Hat.search('"desk1"|string').count.should == 2
  #   Hat.search('"desk1"|string|"someone\'s iHat"').count.should == 3
  #   Hat.search('"desk1"|\'string\'|"someone\'s iHat"').count.should == 3
  # end

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
    Hat.search('feathers>0').count.should == 3
    Hat.search('feathers>2').count.should == 2
    Hat.search('feathers>5').count.should == 1
    Hat.search('feathers>8').count.should == 0
    Hat.search('feathers>=8').count.should == 1
    Hat.search('feathers<8').count.should == 2
    Hat.search('feathers<=5').count.should == 2
  end

  it 'should handle comparisons with dates' do
    Hat.search('fav_date<=1_day_ago').count.should == 3
    Hat.search('fav_date<=15_days_ago').count.should == 2
    Hat.search('fav_date<3_months_ago').count.should == 1
    Hat.search('fav_date<2_years_ago').count.should == 0
  end

  it 'should handle negative comparisons and ORs put together. commands too' do
    Hat.search('-fav_date<2_years_ago').count.should == 3
    Hat.search('-fav_date<3_months_ago').count.should == 2
    Hat.search('-fav_date<=1_day_ago').count.should == 0
    Hat.search('-fav_date<=1_day_ago|fav_date<=1_day_ago').count.should == 3
    Hat.search('-fav_date<=1_day_ago|desk1').count.should == 1
    Hat.search('-fav_date<=1_day_ago|-desk1').count.should == 8
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

  # it 'should error gracefully' do
  #   Hat.search('(-sdf:sdfdf>sd\'s":f-').count.should == 0
  #   Hat.search('""sdfdsfhellosdf|dsfsdf::>>><><').count.should == 0
  # end

  # it 'should handle aliases' do
  #   Hat.search('proc').count.should == 2
  #   Hat.search('string').count.should == 1
  #   Hat.search('hash').count.should == 1
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
