load(__dir__ + '/../spec_helper.rb')

require('mongoid')
require('active_record')
require('sqlite3')
require('mysql2')
require('pg')

unless ENV['MONGOID_CONFIGURED']
  ENV['MONGOID_CONFIGURED'] = 'true'
  Mongoid.configure do |config|
    config.clients.default = {
      hosts: ['localhost:27017'],
      database: 'mongoid_test'
    }
  end
  Mongo::Logger.logger.level = Logger::FATAL
end
