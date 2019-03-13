require('pg')
require('active_record')

db_config = YAML.load_file(__dir__ + '/postgres.yml')
ActiveRecord::Base.establish_connection(db_config['test'])

ActiveRecord::Schema.define do
  create_table :hats, force: true do |t|
    t.string :color
  end
end

class Hat < ActiveRecord::Base
end

Hat.create(color: 'red')

puts Hat.count
