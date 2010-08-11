@snowflake_settings = DaemonKit::Config.load('snowflake.yml').to_h(true)
@snowflake_settings[:logger] = DaemonKit.logger

require 'snowflake'

puts "Connecting to Snowflake with #{@snowflake_settings.inspect}"
Snowflake.connect( @snowflake_settings )