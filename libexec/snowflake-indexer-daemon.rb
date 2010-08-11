# Change this file to be a wrapper around your daemon code.
require 'json'
require 'indexed_element'
include Snowflake::Indexer

def shutdown  
  DaemonKit.logger.info "Waiting for children to finish"
  results = Process.waitall
  
  DaemonKit.logger.info "Children finished!"

  # check the results
  
  results = results.delete_if {|result| result.last.exited? && result.last.success? }
  
  unless results.empty?
    DaemonKit.logger.info "Not all children completed successfully"
    results.each do |result|
      DaemonKit.logger.info "\tChildren Process #{result.first} had a problem: #{result.last.inspect}"
    end
  end

  DaemonKit.logger.info "Shutting Down..."
  DaemonKit.logger.info "Bye!"
end

parent_pid = Process.pid

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap( 'INT' ) do
    # do something clever
  end

  config.trap( 'TERM', Proc.new { 
    DaemonKit.logger.info 'Shutting down' 
  })
end

DaemonKit.logger.info "PID: #{parent_pid}"

elements = @indexer_config[:elements].inject({}) do |elements, e|
  element  = IndexedElement.new( e['name'], e['indices'] )
  elements[element.pattern] = element
  elements
end

children = {}

Snowflake.connection.psubscribe( *elements.keys ) do |on|
  on.psubscribe do |pattern, total|
    DaemonKit.logger.info "Subscribed to #{pattern.inspect}, with total #{total}"
  end

  on.pmessage do |pattern, channel, message|
    # DaemonKit.logger.info "Received from #{channel} (#{pattern.inspect}): #{message}"

    # @todo find someway to escape control chars ("::", ":", and ",")

    # We explcitly ignore updates to mata data (keys that include ::), right now. This is 
    # only because I haven't thought through the consequencies of dealing with them yet.
    unless channel.include?('::')
      # channel_separator = meta ? '::' : ':'
      element, *key = channel.split( ':' )
# puts message
      payload = JSON.parse( message )
      event = payload.delete('event').to_sym

# puts event
      if elements.include?( pattern )
        # Check if it's a legal event
        unless [:create, :update, :destroy, :rename].include?( event )
          # @todo report error
          puts "Illegal Instruction '#{event}'"
        end

        # @todo check errors
        # @todo catch exceptions
        # @todo report errors
        
        pid = Process.fork do
          trap("INT") {
          }

          trap("TERM") {
          }
          
          trap("USR1") {
          }

          trap("USR2") {
          }

          trap("HUP") {
          }

          # Get our own connection, rather than sharing our parents
          Snowflake.connection = Redis.new( Snowflake.options )

          # now we're in the child process; trap (Ctrl-C) interrupts and
          # exit immediately instead of dumping stack to stderr.
          # trap('INT') { exit }

          case event
          when :create
            DaemonKit.logger.info "CREATE #{key.first}"
            elements[pattern].create(key.first, payload['attributes'] )
          when :update
            DaemonKit.logger.info "UPDATE #{key.first}"
            elements[pattern].update(key.first, payload['changes'] )
          when :destroy
            DaemonKit.logger.info "DESTROY #{key.first}"
            elements[pattern].destroy(key.first, payload['attributes'] )
          when :rename
            DaemonKit.logger.info "RENAME #{key.first}"
            elements[pattern].rename(key.first, payload['old_key'], payload['attributes'] )
          end
          
          # @todo check errors
          # @todo catch exceptions
          # @todo report errors
        end
      end
    end
    
    # @todo zset indices
    


    # Respond to the different events: creation, update, destroy, rename
    # event::type::key::
    # create
    # update
    # destroy
    # rename::old_key
  end

  on.punsubscribe do |pattern, total|
    DaemonKit.logger.info "Unsubscribed to #{pattern.inspect}, with total #{total}"
  end
end