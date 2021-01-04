$INTEGRATION_SPECS_CONFIGURED ||= false
return if $INTEGRATION_SPECS_CONFIGURED
$INTEGRATION_SPECS_CONFIGURED = true

load(__dir__ + '/../spec_helper.rb')

require('mongoid')
require('active_record')
require('sqlite3')
require('mysql2')
require('pg')

Mongoid.configure do |config|
  config.clients.default = {
    hosts: ['localhost:27017'],
    database: 'mongoid_test'
  }
end
Mongo::Logger.logger.level = Logger::FATAL

# mysql_db_name = 'command_search_db_test'
# DB = Mysql2::Client.new(
#   host: '127.0.0.1',
#   port:  '3306',
#   username: 'root',
# )
# DB.query("DROP DATABASE IF EXISTS #{mysql_db_name}")
# DB.query("CREATE DATABASE #{mysql_db_name}")
# DB.select_db(mysql_db_name)
