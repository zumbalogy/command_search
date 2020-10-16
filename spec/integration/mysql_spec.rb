load(__dir__ + '/../spec_helper.rb')

module MySQL_Spec

  db_name = 'command_search_db_test'
  DB = Mysql2::Client.new(
    host: ENV.fetch("MYSQL_HOST") { '127.0.0.1' },
    port:  ENV.fetch("MYSQL_PORT") { '3306' },
    username: 'root',
  )

  DB.query("DROP DATABASE IF EXISTS #{db_name}")
  DB.query("CREATE DATABASE #{db_name}")
  DB.select_db(db_name)
  puts DB.query('SHOW VARIABLES').to_a
  DB_VERSION = DB.query('SHOW VARIABLES WHERE Variable_name = "version"').first['Value']
  DB_COMMENT = DB.query('SHOW VARIABLES WHERE Variable_name = "version_comment"').first['Value']

  hat_schema = "
    Title TEXT,
    Description TEXT,
    State TEXT,
    Tags TEXT,
    Starred Boolean,
    Child_id TEXT,
    Feathers INT,
    Feathers2 INT,
    Cost INT,
    Fav_date DATETIME,
    Fav_date2 DATETIME
  "
  DB.query("CREATE TABLE IF NOT EXISTS Hats(Id INTEGER PRIMARY KEY, #{hat_schema})")
  DB.query("CREATE TABLE IF NOT EXISTS Bats1(Id INTEGER PRIMARY KEY, Fav_date DATE)")
  DB.query("CREATE TABLE IF NOT EXISTS Bats2(Id INTEGER PRIMARY KEY, Fav_date DATETIME)")

  class Hat
    E = (0..9999999).each
    def self.create(attrs)
      raw_vals = attrs.values.map do |x|
        next x if x.is_a?(Numeric)
        next "'#{x.gsub("'", "''")}'" if x.is_a?(String)
        next x if x.is_a?(FalseClass)
        next x if x.is_a?(TrueClass)
        x = x.strftime('%Y-%m-%d %H:%M:%S') if x.is_a?(Time)
        x = x.strftime('%Y-%m-%d %H:%M:%S') if x.is_a?(Date)
        x = x.strftime('%Y-%m-%d %H:%M:%S') if x.is_a?(DateTime)
        "'#{x}'"
      end
      vals = raw_vals.join(',')
      keys = attrs.keys.join(',')
      DB.query("INSERT INTO Hats(Id, #{keys}) VALUES(#{E.next}, #{vals})")
    end

    def self.all
      DB.query('SELECT * FROM Hats')
    end

    def self.search(query)
      head_border = '(?<=^|\s|[|(-])'
      tail_border = '(?=$|\s|[|)])'
      sortable_field_names = ['title', 'description']
      sort_field = 'id'
      options = {
        fields: {
          child_id: Boolean,
          title: { type: String, general_search: true },
          name: :title,
          description: { type: String, general_search: true },
          desc: :description,
          starred: Boolean,
          star: :starred,
          tags: { type: String, general_search: true },
          tag: :tags,
          feathers: { type: Numeric, allow_existence_boolean: true },
          feathers2: { type: Numeric, allow_existence_boolean: true },
          cost: Numeric,
          fav_date: Time,
          fav_date2: { type: Time, allow_existence_boolean: true }
        },
        aliases: {
          /#{head_border}sort:\S+#{tail_border}/ => proc { |match|
            match_sort = match.sub(/^sort:/, '')
            sort_field = match_sort if sortable_field_names.include?(match_sort)
            nil
          }
        }
      }
      version = :mysql
      version = :mysqlV5 if DB_VERSION[0] == '5' || DB_COMMENT[/maria/i]
      sql_query = CommandSearch.build(version, query, options)
      return DB.query("SELECT * FROM Hats ORDER BY `#{sort_field}`") unless sql_query.length > 0
      DB.query("SELECT * FROM Hats WHERE #{sql_query} ORDER BY `#{sort_field}`")
    end
  end

  describe Hat do

    before(:each) do
      DB.query('DELETE FROM Hats')
      DB.query('DELETE FROM Bats1')
      DB.query('DELETE FROM Bats2')
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
      Hat.create(title: 'ann of blue beaches')
      Hat.create(title: 'anne')
      Hat.create(title: 'nne')
      Hat.create(title: 'nn')
      Hat.create(title: 'zz zyx')
      Hat.search('"ann"').count.should == 2
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
      Hat.create(title: '(+d)')
      Hat.create(title: 'x,y,z')
      Hat.search('title:+').count.should == 9
      Hat.search('+').count.should == 9
      Hat.search('title:+a').count.should == 3
      Hat.search('+a').count.should == 3
      Hat.search('title:a+').count.should == 5
      Hat.search('a+').count.should == 5
      Hat.search('title:"a+"').count.should == 2
      Hat.search('"a+"').count.should == 2
      Hat.search('title:b+').count.should == 1
      Hat.search('b+').count.should == 1
      Hat.search('title:"b+"').count.should == 1
      Hat.search('"b+"').count.should == 1
      Hat.search('title:"c"').count.should == 1
      Hat.search('"c"').count.should == 1
      Hat.search('title:"c?"').count.should == 1
      Hat.search('title:"+d"').count.should == 1
      Hat.search('title:"(+d)"').count.should == 1
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

    it 'should be able to handle SQL GLOB characters' do
      Hat.create(title: 'z?')
      Hat.create(title: 'z-')
      Hat.create(title: 'xy')
      Hat.create(title: 'x')
      Hat.create(title: 'y')
      Hat.create(title: '[xy]')
      Hat.create(title: 'a*b')
      Hat.create(title: 'aa*b')
      Hat.create(title: 'hello?!?')
      Hat.search('"a*b"').count.should == 1
      Hat.search('a[*]b').count.should == 0
      Hat.search('[a]').count.should == 0
      Hat.search('[xy]').count.should == 1
      Hat.search('z?').count.should == 1
      Hat.search('"z?"').count.should == 1
      Hat.search('hello').count.should == 1
      Hat.search('hello???').count.should == 0
      Hat.search('"hello???"').count.should == 0
      Hat.search('hello?!?').count.should == 1
      Hat.search('"hello?!?"').count.should == 1
    end

    it 'should be able to handle SQL LIKE characters' do
      Hat.create(title: 'hello_world')
      Hat.create(title: 'hello-world')
      Hat.create(title: 'hello world')
      Hat.create(title: 'hello__world')
      Hat.create(title: 'hello--world')
      Hat.create(title: 'hello%world')
      Hat.create(title: 'hello%%world')
      Hat.search('title:hello_world').count.should == 1
      Hat.search('hello_world').count.should == 1
      Hat.search('"hello_world"').count.should == 1
      Hat.search('title:hello-world').count.should == 1
      Hat.search('hello-world').count.should == 1
      Hat.search('title:hello__world').count.should == 1
      Hat.search('hello__world').count.should == 1
      Hat.search('title:hello--world').count.should == 1
      Hat.search('hello--world').count.should == 1
      Hat.search('title:hello--worl%').count.should == 0
      Hat.search('hello--worl%').count.should == 0
      Hat.search('"hello--worl%"').count.should == 0
      Hat.search('title:hello%world').count.should == 1
      Hat.search('hello%world').count.should == 1
      Hat.search('title:hello%%world').count.should == 1
      Hat.search('hello%%world').count.should == 1
      Hat.search('"hello%%world"').count.should == 1
    end

    it 'should be able to search for a boolean' do
      Hat.create(title: 'foo', starred: true)
      Hat.create(title: 'bar', starred: true)
      Hat.create(title: 'bar 2', starred: false)
      Hat.search('starred:true').count.should == 2
      total = Hat.search('starred:false').count + Hat.search('starred:true').count
      Hat.all.count.should == total
    end

    it 'should check for existance if passed a boolean for a string field' do
      Hat.create(title: 'foo', child_id: 'foo')
      Hat.create(title: 'batz', child_id: 'bar')
      Hat.search('child_id:true').count.should == 2
    end

    it 'should be able to find things from the description' do
      Hat.search('desk').count.should == 4
      Hat.search('desk2').count.should == 1
      Hat.search('desk2 2').count.should == 1
      Hat.search('2').count.should == 3
    end

    it 'should be able to find things from the tags' do
      Hat.search('tags1').count.should == 1
      Hat.search('tags').count.should == 2
      Hat.search('multi tag').count.should == 1
      Hat.search("'quoted tag'").count.should == 1
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
    end

    it 'should be able to find things with commands' do
      Hat.search('title:name1').count.should == 1
      Hat.search('title:name500').count.should == 0
      Hat.search('feathers:5').count.should == 1
      Hat.search('cost:0').count.should == 1
      Hat.search('cost:0.0').count.should == 1
      Hat.search('cost:-0.0').count.should == 1
      Hat.search('cost:-0').count.should == 1
    end

    it 'should handle numeric existence checks' do
      Hat.search('feathers:true').count.should == 3
      Hat.search('feathers:false').count.should == 6

      Hat.create(feathers2: 12)
      Hat.create(feathers2: 1)
      Hat.create(feathers2: 100)
      Hat.create(feathers2: 0)
      Hat.search('feathers2:true').count.should == 3
      Hat.search('feathers2:false').count.should == 10
      Hat.search('feathers2>5').count.should == 2
      Hat.search('feathers2>-5').count.should == 4
      Hat.search('feathers2>"-5"').count.should == 4
      Hat.search('feathers2>foo').count.should == 0

      Hat.create(fav_date2: Time.new(1,1,1,0,0,0,0))
      Hat.search('fav_date2<1234').count.should == 1
      Hat.search('fav_date2>1234').count.should == 0

      Hat.search('feathers2>=-33').count.should == 4
      Hat.search('feathers2<=-33').count.should == 0
      Hat.create(feathers2: -33)
      Hat.search('feathers2>=-33').count.should == 5
      Hat.search('feathers2<=-33').count.should == 1
      Hat.search('feathers2>-35').count.should == 5
      Hat.search('feathers2<-30').count.should == 1
    end

    it 'should be able to find things with aliased commands' do
      Hat.search('tags:tags1').count.should == 1
      Hat.search('tag:tags1').count.should == 1
    end

    it 'should be able to find things with quoted commands' do
      Hat.search("tag:'quoted tag'").count.should == 1
      Hat.search("tags:'quoted tag'").count.should == 1
    end

    it 'should be able to find things with multiple commands' do
      Hat.search('tags:tags2 title:name4').count.should == 1
    end

    it 'should be able to find things with commands and searches' do
      Hat.search('tags:tags1 name3').count.should == 1
      Hat.search('name3 desc:desk2').count.should == 1
    end

    it 'should be able to to multiple quoted and aliased commands with multiple searches' do
      Hat.search('tag:tags1 title:name3 name desk').count.should == 1
    end

    it 'should handle quoted apostrophes' do
      Hat.search("\"someone's iHat\"").count.should == 1
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
      Hat.search('cost<=cost').count.should == 3 # nil does not eq nil in this case.
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

    it 'should handle bad date inputs' do
      Hat.search('fav_date<zxcvbn').count.should == 0
      Hat.search('fav_date<(**4h)').count.should == 0
      Hat.search('fav_date<=(**4h)').count.should == 0
      Hat.search('fav_date>(**4h)').count.should == 0
      Hat.search('fav_date>=(**4h)').count.should == 0
      Hat.search('fav_date:').count.should == 0
      Hat.search('fav_date:::').count.should == 0
      Hat.search('fav_date:u48jt0').count.should == 0
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
      Hat.search('sort:title').map { |x| x.values[1] }.should == sorted_titles
      Hat.search('sort:bad_key_that_is_unsearchable').map { |x| x.values[1] }.should_not == sorted_titles
      Hat.search('').map { |x| x.values[1] }.should_not == sorted_titles
      Hat.search('sort:description').map { |x| x.values[2] }.should == sorted_desc
      Hat.search('sort:sdfluho').map { |x| x.values[2] }.should_not == sorted_desc
      Hat.search('').map { |x| x.values[2] }.should_not == sorted_desc
    end

    it 'should handle different time data types' do
      class Bat1
        def self.search(query, options)
          sql_query = CommandSearch.build(:mysql, query, options)
          DB.query("SELECT * FROM Bats1 WHERE #{sql_query}")
        end
      end

      class Bat2
        def self.search(query, options)
          sql_query = CommandSearch.build(:mysql, query, options)
          DB.query("SELECT * FROM Bats2 WHERE #{sql_query}")
        end
      end

      E = (0...999999999).each
      def make_bats(fav_date)
        e = E.next()
        DB.query("INSERT INTO Bats1(Id, Fav_date) VALUES(#{e}, '#{fav_date.strftime('%Y-%m-%d %H:%M:%S')}')")
        DB.query("INSERT INTO Bats2(Id, Fav_date) VALUES(#{e}, '#{fav_date.strftime('%Y-%m-%d %H:%M:%S')}')")
      end

      def search_bats(query, total)
        [Date, Time, DateTime].each do |klass|
          Bat1.search(query, { fields: { fav_date: klass }}).count.should == total
          Bat2.search(query, { fields: { fav_date: klass }}).count.should == total
        end
      end

      make_bats(DateTime.new(1000))
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
      Hat.search('-panda').count.should == Hat.all.count - 2
      Hat.search('-(penguin panda)').count.should == Hat.all.count - 1
      Hat.search('-(penguin|panda)').count.should == Hat.all.count - 3
      Hat.search('-(penguin panda) panda').count.should == 1
      Hat.search('-(penguin panda) penguin').count.should == 1
      Hat.search('-(penguin panda) penguin panda').count.should == 0
      Hat.search('-(penguin -panda) panda').count.should == 2
      Hat.search('-(-penguin panda) panda').count.should == 1
    end

    it 'should handle wacky things' do
      Hat.search('-(zzz)|"b"').count.should == 9
      # TODO: think about wither or not a special case should be made for ""
      # Hat.create(description: '')
      # Hat.search('description:""').count.should == 1
      # Hat.create(description: '')
      # Hat.search('description:""').count.should == 2
    end
  end
end
