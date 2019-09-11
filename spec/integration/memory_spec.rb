load(__dir__ + '/../spec_helper.rb')

$hats = [
  { title: 'name name1 1', description: '' },
  { title: 'name name2 2', description: 'desk desk1 1' },
  { title: 'name name3 3', description: 'desk desk2 2', tags: 'tags, tags1, 1' },
  { title: 'name name4 4', description: 'desk desk3 3', tags: 'tags, tags2, 2' },
  { description: "desk new \n line" },
  { tags: "multi tag, 'quoted tag'" },
  { title: 'same_name', feathers: 2, cost: 0, fav_date: Chronic.parse('2 months ago') },
  { title: 'same_name', feathers: 5, cost: 4, fav_date: Chronic.parse('1 year ago') },
  { title: "someone's iHat", feathers: 8, cost: 100, fav_date: Chronic.parse('1 week ago') }
]

def search(query, list = $hats)
  options = {
    fields: [:title, :description, :tags],
    command_fields: {
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
  }
  CommandSearch.search(list, query, options)
end

describe CommandSearch::Memory do

  it 'should be able to do an empty string query' do
    search('').count.should == $hats.count
    search('desc:""').count.should == 1
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

  it 'should be able to handle special syntax' do
    foo = [
      { title: '+' },
      { title: 'a+' },
      { title: 'a++' },
      { title: '+a' },
      { title: '+a+' },
      { title: 'a+a' },
      { title: '.a+.' },
      { title: '(b+)' },
      { title: 'c?' },
      { title: 'x,y,z' }
    ]
    search('title:+', foo).count.should == 8
    search('+', foo).count.should == 8
    search('title:+a', foo).count.should == 3
    search('+a', foo).count.should == 3
    search('title:a+', foo).count.should == 5
    search('a+', foo).count.should == 5
    search('title:"a+"', foo).count.should == 2
    search('"a+"', foo).count.should == 2
    search('title:"b+"', foo).count.should == 1
    search('"b+"', foo).count.should == 1
    search('title:"c"', foo).count.should == 1
    search('"c"', foo).count.should == 1
    search('title:"c?"', foo).count.should == 1
    search('"c?"', foo).count.should == 1
    search('y', foo).count.should == 1
    search('y z', foo).count.should == 1
    search('title:"z"', foo).count.should == 1
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
    search('fav_date<="1 day ago"').count.should == 3
    search('fav_date<=15_days_ago').count.should == 2
    search('fav_date<=15-days.ago').count.should == 2
    search('fav_date<3_months_ago').count.should == 1
    search('fav_date<2_years_ago').count.should == 0
    search('fav_date>1/1/1900').count.should == 3
    search('fav_date>=1/1/1900').count.should == 3
    search("#{Time.now.year + 10}>fav_date>=1/1/1900").count.should == 3
  end

  it 'should handle negative comparisons and ORs put together. commands too' do
    search('fav_date<2_years_ago').count.should == 0
    search('-fav_date<2_years_ago').count.should == 9
    search('-fav_date<3_months_ago').count.should == 8
    search('-fav_date<=1_day_ago').count.should == 6
    search('-fav_date<=1_day_ago|fav_date<=1_day_ago').count.should == 9
    search('-fav_date<=1_day_ago|desk1').count.should == 6
    search('-fav_date<=1_day_ago|-desk1').count.should == 9

    hats2 = [
      { title: 'penguin', description: 'panda'},
      { description: 'panda'},
      { title: 'penguin'}
    ]
    search('panda', hats2).count.should == 2
    search('-panda', hats2).count.should == 1
    search('-(penguin panda)', hats2).count.should == 2
    search('-(penguin|panda)', hats2).count.should == 0
    search('-(penguin panda) panda', hats2).count.should == 1
    search('-(penguin panda) penguin', hats2).count.should == 1
    search('-(penguin panda) penguin panda', hats2).count.should == 0
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
    CommandSearch.search([{foo: 3}], '2', { fields: ['foo'] }).count.should == 0
    CommandSearch.search([{foo: 3}], '2', { fields: [:foo] }).count.should == 0
    CommandSearch.search([{foo: 3}], '3', { fields: ['foo'] }).count.should == 1
    CommandSearch.search([{foo: 3}], '3', { fields: [:foo] }).count.should == 1
    CommandSearch.search([{'foo' => 3}], '2', { fields: ['foo'] }).count.should == 0
    CommandSearch.search([{'foo' => 3}], '2', { fields: [:foo] }).count.should == 0
    CommandSearch.search([{'foo' => 3}], '3', { fields: ['foo'] }).count.should == 1
    CommandSearch.search([{'foo' => 3}], '3', { fields: [:foo] }).count.should == 1
  end

  it 'should handle unicode' do
      fields = { fields: [:a] }
      CommandSearch.search([{ a: '😀🤔😶🤯🇦🇶🏁🆒⁉🚫📡🔒💲👠♦🔥♨🌺🌿💃🙌👍👌👋💯❤💔' }], '💯', fields).count.should == 1
      CommandSearch.search([{ a: '😀🤔😶🤯🇦🇶🏁🆒⁉🚫📡🔒💲👠♦🔥♨🌺🌿💃🙌👍👌👋💯❤💔' }], '🔥♨', fields).count.should == 1
      CommandSearch.search([{ a: '😀🤔😶🤯🇦🇶🏁🆒⁉🚫📡🔒💲👠♦🔥♨🌺🌿💃🙌👍👌👋💯❤💔' }], '🔥♨🔥♨', fields).count.should == 0
      CommandSearch.search([{ a: '😀🤔😶🤯🇦🇶🏁🆒⁉🚫📡🔒💲👠♦🔥♨🌺🌿💃🙌👍👌👋💯❤💔' }], '🔥♨🌺🌿 🔒 😀', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello👋', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello👋👋', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello👋👋👋', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello 👋👋👋👋', fields).count.should == 0
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello 👋👋👋', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello 👋👋', fields).count.should == 1
      CommandSearch.search([{ a: 'hello👋👋👋' }], 'hello 👋', fields).count.should == 1
      CommandSearch.search([{ a: 'こんにちは世界' }], '世界', fields).count.should == 1
      CommandSearch.search([{ a: 'こんにちは世界' }], '月', fields).count.should == 0
      CommandSearch.search([{ a: 'こんにちは世界' }], 'world', fields).count.should == 0
      CommandSearch.search([{ a: 'こんにちは世界' }], 'moon', fields).count.should == 0
      CommandSearch.search([{ a: 'හෙලෝ වර්ල්ඩ්' }], 'වර්ල්ඩ්', fields).count.should == 1
      CommandSearch.search([{ a: 'හෙලෝ වර්ල්ඩ්' }], 'හඳ', fields).count.should == 0
      CommandSearch.search([{ a: 'សួស្តី​ពិភពលោក' }], 'ពិភពលោក', fields).count.should == 1
      CommandSearch.search([{ a: 'សួស្តី​ពិភពលោក' }], 'ព្រះ​ច័ន្ទ', fields).count.should == 0
      CommandSearch.search([{ a: 'ສະ​ບາຍ​ດີ​ຊາວ​ໂລກ' }], 'ໂລກ', fields).count.should == 1
      CommandSearch.search([{ a: 'ສະ​ບາຍ​ດີ​ຊາວ​ໂລກ' }], 'ເດືອນ', fields).count.should == 0
  end

  it 'should handle different time data types' do
    list = [{ foo: Date.new(1000) }, { foo: Time.now }, { foo: DateTime.now }]
    CommandSearch.search(list, 'foo>1990', { command_fields: { foo: Time } }).count.should == 2
    CommandSearch.search(list, 'foo>1990', { command_fields: { foo: Date } }).count.should == 2
    CommandSearch.search(list, 'foo>1990', { command_fields: { foo: DateTime } }).count.should == 2
    CommandSearch.search(list, 'foo:1000', {  command_fields: { foo: Time } }).count.should == 1
    CommandSearch.search(list, 'foo:1000', { command_fields: { foo: Date } }).count.should == 1
    CommandSearch.search(list, 'foo:1000', { command_fields: { foo: DateTime } }).count.should == 1
    list2 = [{ foo: Time.new('1991') }, { foo: Time.new('1995') }]
    CommandSearch.search(list2, 'foo:1991', { command_fields: { foo: Time } }).count.should == 1
    CommandSearch.search(list2, 'foo<=1991', { command_fields: { foo: Time } }).count.should == 1
    CommandSearch.search(list2, 'foo<2010', { command_fields: { foo: Time } }).count.should == 2
    CommandSearch.search(list2, 'foo:1991', { command_fields: { foo: Date } }).count.should == 1
    CommandSearch.search(list2, 'foo<=1991', { command_fields: { foo: Date } }).count.should == 1
    CommandSearch.search(list2, 'foo<2010', { command_fields: { foo: Date } }).count.should == 2
    CommandSearch.search(list2, 'foo:1991', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list2, 'foo<=1991', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list2, 'foo<2010', { command_fields: { foo: DateTime } }).count.should == 2
    list3 = [{ foo: Time.new('1991-01-01') }, { foo: Time.new('1995') }]
    CommandSearch.search(list3, 'foo:"1991/01/01"', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list3, 'foo:"1991-01-01"', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list3, 'foo:"1995"', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list3, 'foo:"1994"', { command_fields: { foo: DateTime } }).count.should == 0
    CommandSearch.search(list3, 'foo:"1996"', { command_fields: { foo: DateTime } }).count.should == 0
    list4 = [{ foo: Time.new('1995') }, { foo: Time.new(1995, 12, 12) }, { foo: Time.new('1996') }]
    CommandSearch.search(list4, 'foo:"1995"', { command_fields: { foo: DateTime } }).count.should == 2
    CommandSearch.search(list4, 'foo>=1995', { command_fields: { foo: DateTime } }).count.should == 3
    CommandSearch.search(list4, 'foo>=1995-02-03', { command_fields: { foo: DateTime } }).count.should == 2
    # command_search thinks 'foo<=1995' is the same as 'foo<=1995-1-1'.
    CommandSearch.search(list4, 'foo<=1995', { command_fields: { foo: DateTime } }).count.should == 1
    CommandSearch.search(list4, '-foo<=1995', { command_fields: { foo: DateTime } }).count.should == 2
  end

  it 'should not throw errors' do
    CommandSearch.search([{}], "Q)'(':{Mc&hO    T)r", { fields: [:foo] })
    CommandSearch.search([{}], "m3(_:;_[P4ZV<]w)t", { fields: [:foo] })
    CommandSearch.search([{}], " d<1-Tw?.�ey<1.E4:e>cb]", { fields: [:foo] })
    CommandSearch.search([{}], "=4Ts2em(5sZ ]]&x<-", { fields: [:foo] })
    CommandSearch.search([{}], "<|SOUv~Y74+Fm+Yva`64", { fields: [:foo] })
    CommandSearch.search([{}], "4:O0E%~Z<@?O]e'h@<'k^", { fields: [:foo] })

    CommandSearch.search([{}], '(-sdf:sdfdf>sd\'s":f-', { fields: [:foo] })
    CommandSearch.search([{}], '""sdfdsfhellosdf|dsfsdf::>>><><', { fields: [:foo] })

    CommandSearch.search([{}], 'foo:""', { command_fields: { foo: String } })
  end

  it 'should not throw errors in the presence of "naughty strings"' do
    # https://github.com/minimaxir/big-list-of-naughty-strings
    require('json')
    file = File.read(__dir__ + '/../assets/blns.json')
    list = JSON.parse(file)
    check = true
    list.each do |str|
      begin
        CommandSearch.search([{}], str, { fields: [:foo] })
      rescue
        check = false
      end
    end
    check.should == true
  end

  it 'should handle fuzzing' do
    check = true
    10000.times do |i|
      str = (0...24).map { (rand(130)).chr }.join
      begin
        CommandSearch.search([{}], str, { fields: [:foo] })
      rescue
        puts str.inspect
        check = false
        break
      end
    end
    check.should == true
  end

  it 'should handle permutations' do
    check = true
    strs = ['a', 'b', '', ' ', '0', '7', '-', '.', ':', '|', '<', '>', '=', '(', ')', '"', "'"]
    strs.repeated_permutation(4).each do |perm|
      begin
        CommandSearch.search([{}], perm.join, { fields: [:foo] })
      rescue
        puts perm
        check = false
      end
    end
    check.should == true
  end

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
