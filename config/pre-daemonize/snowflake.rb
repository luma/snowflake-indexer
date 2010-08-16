@snowflake_settings = DaemonKit::Config.load('snowflake.yml').to_h(true)

require 'snowflake'

puts "Connecting to Snowflake with #{@snowflake_settings.inspect}"

Snowflake.logger = DaemonKit.logger
Snowflake.connect( @snowflake_settings )