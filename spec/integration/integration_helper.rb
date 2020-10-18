load(__dir__ + '/../spec_helper.rb')

require('mongoid')
require('active_record')
require('sqlite3')
require('mysql2')
require('pg')

unless ENV['MONGOID_CONFIGURED']
  ENV['MONGOID_CONFIGURED'] = 'true'
  Mongoid.configure do |config|
    host = 'localhost'
    port = ENV.fetch("MONGODB_PORT") { '27017' }
    config.clients.default = {
      hosts: ["#{host}:#{port}"],
      database: 'mongoid_test'
    }
  end
  Mongo::Logger.logger.level = Logger::FATAL
end
