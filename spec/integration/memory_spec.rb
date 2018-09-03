load(__dir__ + '/../spec_helper.rb')

$hats = [
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

def search(query, list = $hats)
  search_fields = [:title, :description, :tags]
  command_fields = {
    has_child_id: Boolean,
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
  }
  CommandSearch.search(list, query, search_fields, command_fields)
end

describe CommandSearch::Memory do

  it 'should be able to do an empty string query' do
    search('').count.should == $hats.count
  end

  it 'should be able to do specific matches' do
    hats2 = [
      { title: 'ann' },
      { title: 'anne' },
      { title: 'nne' },
      { title: 'nn' }
    ]
    search('"ann"', hats2).count.should == 1
    search('"nn"', hats2).count.should == 1
    search('"nne"', hats2).count.should == 1
  end

  it 'should be able to search for a boolean' do
    star_list = [
     { title: 'foo', starred: true },
     { title: 'bar', starred: true },
     { title: 'bar 2', starred: false }
    ]
    search('starred:true', star_list).count.should == 2
    search('starred:false', star_list).count.should == 1
  end

  it 'should check for existance if passed a boolean for a string field' do
    hats2 = [
      { title: 'foo', has_child_id: 'foo' },
      { title: 'batz', has_child_id: 'bar' }
    ]
    search('has_child_id:true', hats2).count.should == 2
    search('has_child_id:false', hats2).count.should == 0
    search('has_child_id:foo', hats2).count.should == 0
  end

  it 'should be able to find things from the description' do
    search('desk').count.should == 4
    search('desk2').count.should == 1
    search('desk2 2').count.should == 1
  end

  it 'should be able to find things from the tags' do
    search('tags1').count.should == 1
    search('tags').count.should == 2
    search('multi tag').count.should == 1
    search("'quoted tag'").count.should == 1
  end

  it 'should be able to find things from the title' do
    search('name1').count.should == 1
    search('name').count.should == 6
    search('same_name').count.should == 2
  end

  it 'should not be case sensitive' do
    search('name1').count.should == 1
    search('Name1').count.should == 1
    search('name').count.should == 6
    search('NAME').count.should == 6
    search('same_name').count.should == 2
    search('samE_NaMe').count.should == 2
  end

  it 'should be able to do case sensitive searches' do
    foo = [{ title: 'fQQ' }]
    search('title:fqq', foo).count.should == 1
    search('title:fQQ', foo).count.should == 1
    search('title:"fQQ"', foo).count.should == 1
    search('title:"fqq"', foo).count.should == 0
  end

  it 'should be able to find things across fields' do
    search('name3 tags1').count.should == 1
    search('name2 desk1').count.should == 1
    search('name2 desk2').count.should == 0
    search('desk3 tags2').count.should == 1
    search('desk0 tags2').count.should == 0
    search('desk3 tags3').count.should == 0
    search('desk3 tags2 name4').count.should == 1
  end

  it 'should be able to find things with new lines' do
    search('new line').count.should == 1
    search('desk new line').count.should == 1
  end

  it 'should be able to find things whatever the order of the searches' do
    search('new desk line').count.should == 1
    search('line new desk').count.should == 1
    search('   line    new    desk   ').count.should == 1
    search('desk3 tags2 name4').count.should == 1
    search('tags2 desk3 tags2 name4 tags2').count.should == 1
  end

  it 'should be able to find things that are quotes' do
    search("'quoted tag'").count.should == 1
    search("multi 'quoted tag'").count.should == 1
  end

  it 'should be able to find things with commands' do
    search('title:name1').count.should == 1
    search('title:name500').count.should == 0
  end

  it 'should handle numeric existance checks' do
    search('feathers:true').count.should == 3
    search('feathers:false').count.should == 6
    search('feathers:8').count.should == 1
  end

  it 'should handle undefined commands' do
    hats2 = [
      { title: 'foo', private: 800 },
      { title: 'bar', private: 80 }
    ]
    search('nam:name1').count.should == 0
    search('title:foo', hats2).count.should == 1
    search('private:80', hats2).count.should == 0
    search('private:12', hats2).count.should == 0
  end

  it 'should be able to find things with aliased commands' do
    search('tags:tags1').count.should == 1
    search('tag:tags1').count.should == 1
  end

  it 'should be able to find things with quoted commands' do
    search("tag:'quoted tag'").count.should == 1
    search("tags:'quoted tag'").count.should == 1
  end

  it 'should be able to find things with multiple commands' do
    search('tags:tags2 title:name4').count.should == 1

  end

  it 'should be able to find things with commands and searches' do
    search('tags:tags1 name3').count.should == 1
    search('name3 desc:desk2').count.should == 1
  end

  it 'should be able to to multiple quoted and aliased commands with multiple searches' do
    search('tag:tags1 title:name3 name desk').count.should == 1
  end

  it 'should be chainable with other searches' do
    search('title:name2', search('desc:desk1 2')).count.should == 1
  end

  it 'should handle quoted apostrophes' do
    search("\"someone's iHat\"").count.should == 1
    search("title:\"someone's iHat\"").count.should == 1
    search("title:\"someone's iHat\"|name4").count.should == 2
  end

  it 'should handle OR searches' do
    search('name2|name3').count.should == 2
    search('name2|name3|name4').count.should == 3
    search('name2|name3|desk2').count.should == 2
    search('name2|name3|desk2|bad_search_sdfsdf').count.should == 2
  end

  it 'it should handle OR searches with other searches' do
    search('name2|name3 name2').count.should == 1
    search('name2|name3 name4').count.should == 0
    search('name4 name2|name3').count.should == 0
    search('desk3 name2|name3').count.should == 0
    search('desk2 name2|name3').count.should == 1
    search('desk2 name2|name3|desk2').count.should == 1
    search('desk2 name2|name3|desk3').count.should == 1
  end

  it 'it should handle multiple OR searches' do
    search('desk1|desk2 desk2|desk3').count.should == 1
    search('desk1|desk2 desk2||desk3').count.should == 1
    search('desk1|desk2 desk2|||desk3').count.should == 1
    search('desk1||desk2 desk2|||desk3').count.should == 1
    search('desk1|desk2 desk1|desk2').count.should == 2
    search('desk1|desk2|desk3 desk1|desk2').count.should == 2
    search('desk1|desk2|desk3 desk1|desk3|desk2').count.should == 3
    search('desk1||desk2|desk3 desk1|||desk3|desk2').count.should == 3
  end

  it 'it should handle multiple OR searches with command and non command searches' do
    search('tags:tags2|tags:tags1').count.should == 2
    search('tags:tags2|tags:tags1|tags:tags2').count.should == 2
    search('tags:tags2|tags:tags1|tags:tags9').count.should == 2
    search('tags:tags2|tags1').count.should == 2
    search('tags:tags2|tags1 tags1').count.should == 1
    search('tags:tags2|tags1 tags:tags1').count.should == 1
    search('tags:tags2|tags1 tags:tags2').count.should == 1
  end

  it 'should handle ORs with quotes' do
    # q.alias_fields[/^string$/i] = 'desk2'
    search('desk1|desk2').count.should == 2
    search('desk1|"desk2"').count.should == 2
    search("desk1|'desk2'").count.should == 2
    search("'desk1'|'desk2'").count.should == 2
    search('"desk1"|"desk2"').count.should == 2
    search("'desk1'|desk2").count.should == 2
    search('"desk1"|desk2').count.should == 2
    search('"desk1"|"de|sk2"').count.should == 1
    search('"desk1"|desk2|"someone\'s iHat"').count.should == 3
    search('"desk1"|\'desk2\'|"someone\'s iHat"').count.should == 3
  end

  # it 'should handle regex aliases' do
  #   # q.alias_fields[/^string$/i] = 'desk2'
  #   search('desk1|string').count.should == 2
  #   search('desk1|"string"').count.should == 2
  #   search("desk1|'string'").count.should == 2
  #   search("'desk1'|'string'").count.should == 2
  #   search('"desk1"|"string"').count.should == 2
  #   search("'desk1'|string").count.should == 2
  #   search('"desk1"|string').count.should == 2
  #   search('"desk1"|string|"someone\'s iHat"').count.should == 3
  #   search('"desk1"|\'string\'|"someone\'s iHat"').count.should == 3
  # end

  it 'it should handle negative searches' do
    check = 9
    search('').count.should == check
    (search('tags1').count + search('-tags1').count).should == check
    (search('tags:tags1').count + search('-tags:tags1').count).should == check
    (search('tags1 tags2').count + search('-tags1|-tags2').count).should == check
  end

  it 'it should handle multiple searches some negative' do
    search('-tags1 -tags2').count.should == 7
    search('tags1 -tags2').count.should == 1
    search('tags2 -tags2').count.should == 0
    search('tags1 -tags:tags2').count.should == 1
    search('tags:tags1 -tags2').count.should == 1
    search('tags:tags1 -tags:tags2').count.should == 1
  end

  it 'should handle comparisons' do
    search('0<feathers').count.should == 3
    search('feathers>0').count.should == 3
    search('feathers>2').count.should == 2
    search('feathers>5').count.should == 1
    search('feathers>8').count.should == 0
    search('feathers>=8').count.should == 1
    search('feathers<8').count.should == 2
    search('feathers<=5').count.should == 2
    search('feathers<cost').count.should == 1
    search('feathers>cost').count.should == 2
    search('cost>cost').count.should == 0
    # search('cost<=cost').count.should == $hats.count // TODO: ones without a cost are currenty just not matched
    # which seems to differ from the mongoid $gt and all. worth looking into.
  end

  it 'should handle chained comparisons' do
    search('100>feathers>0').count.should == 3
    search('0<feathers>2').count.should == 2
    search('0<feathers<cost').count.should == 1
    search('feathers>=cost>0').count.should == 1
    search('feathers>=cost>=0').count.should == 2
    search('-5<feathers>=cost>=0').count.should == 2
    search('0<feathers<cost<200').count.should == 1
  end

  it 'should handle comparisons with dates' do
    search('fav_date<=1_day_ago').count.should == 3
    search('fav_date<=15_days_ago').count.should == 2
    search('fav_date<=15-days.ago').count.should == 2
    search('fav_date<3_months_ago').count.should == 1
    search('fav_date<2_years_ago').count.should == 0
    search('fav_date>1/1/1900').count.should == 3
  end

  it 'should handle negative comparisons and ORs put together. commands too' do
    # NOTE: Unlike mongo version, items that dont have a key are returned
    # in the negation case. so if the search is "-foo" an item {bar: 5} will be
    # returned
    search('fav_date<2_years_ago').count.should == 0
    search('-fav_date<2_years_ago').count.should == 9
    search('-fav_date<3_months_ago').count.should == 8
    search('-fav_date<=1_day_ago').count.should == 6
    search('-fav_date<=1_day_ago|fav_date<=1_day_ago').count.should == 9
    search('-fav_date<=1_day_ago|desk1').count.should == 6
    search('-fav_date<=1_day_ago|-desk1').count.should == 9
  end

  it 'should handle nesting via parentheses' do
    search('-(-desk1)').count.should == 1
    search('(desk1 name2) | desk3').count.should == 2
    search('(desk1 name2) | desk3').count.should == 2
    hats2 = [
      { title: 'a9 b9' },
      { title: 'b9 c9' },
      { title: 'c9 d9' }
    ]
    search('(a9 b9) | (c9|d9)', hats2).count.should == 3
    search('(a9 b9) | (c9 d9)', hats2).count.should == 2
    search('(a9 b9) (c9 d9)', hats2).count.should == 0
  end

  it 'should handle quesiton marks without error' do
    search('?').count.should == 0
    search('(?)').count.should == 0
    search('(redgreenblue01?)').count.should == 0
  end

  it 'should be able to work with strings and symbols' do
    CommandSearch.search([{foo: 3}], '2', ['foo']).count.should == 0
    CommandSearch.search([{foo: 3}], '2', [:foo]).count.should == 0
    CommandSearch.search([{foo: 3}], '3', ['foo']).count.should == 1
    CommandSearch.search([{foo: 3}], '3', [:foo]).count.should == 1
    CommandSearch.search([{'foo' => 3}], '2', ['foo']).count.should == 0
    CommandSearch.search([{'foo' => 3}], '2', [:foo]).count.should == 0
    CommandSearch.search([{'foo' => 3}], '3', ['foo']).count.should == 1
    CommandSearch.search([{'foo' => 3}], '3', [:foo]).count.should == 1
  end

  # it 'should error gracefully' do
  #   lopsided parens
  #   search('(-sdf:sdfdf>sd\'s":f-').count.should == 0
  #   search('""sdfdsfhellosdf|dsfsdf::>>><><').count.should == 0
  # end

  # it 'should handle aliases' do
  #   search('proc').count.should == 2
  #   search('string').count.should == 1
  #   search('hash').count.should == 1
  # end

  # it 'should handle searching ones that are not specified and also wierd hash ones' do
  #   search('custom_s:penn').count.should == 1
  #   search('penn').count.should == 0
  #   search('custom_s:"penn station"').count.should == 1
  #   search('custom_h.id:foo').count.should == 1
  #   search('foo').count.should == 0
  #   search('id:foo').count.should == 0
  #   search('custom_h:foo').count.should == 0
  #   search('custom_h_id:foo').count.should == 0
  #   search('custom_h.id:bar').count.should == 0
  # end

end
