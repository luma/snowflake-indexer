module Snowflake
  module Indexer
    class IndexedElement
      attr_reader :name, :indices, :pattern
      def initialize(name, indices)
        @name, @indices = name, indices
        @pattern = "#{@name}*"
      end

      def create(key, *fields)
        Snowflake.connection.multi do
          DaemonKit.logger.info "\t#{@name}: Adding #{key.inspect} to all"
          Snowflake.connection.sadd( Keys.meta_key_for( @name, 'indices', 'all' ), key )

          Hash[*fields].each do |field, value|
            if @indices.include?( field )
              DaemonKit.logger.info "\t#{@name}: Adding #{value.inspect} to #{field}"
              
              add_value_to_index(key, field, value)
            end
          end

          # @todo deal with custom attributes
        end
      end

      def update(key, *changes)
        Snowflake.connection.multi do
          # @todo changes should be all fields, not just those with data (i.e. include fields with values of nil)
          Hash[*changes].each do |field, values|
            if @indices.include?( field )
              DaemonKit.logger.info "\t#{@name}: Updating #{value.first.inspect} to #{value.last.inspect} on #{field}"

              #Snowflake.connection.srem( Keys.meta_key_for( @name, 'indices', field, values.first ), key )
              remove_value_from_index(key, field, value.first)

              if values.last != nil
                #Snowflake.connection.sadd( Keys.meta_key_for( @name, 'indices', field, values.last ), key )
                add_value_to_index(key, field, value.last)
              end
            end
          end

          # @todo deal with custom attributes
        end
      end

      def destroy(key, *fields)
        Snowflake.connection.multi do
          DaemonKit.logger.info "\t#{@name}: Removing #{key.inspect} from all"
          Snowflake.connection.srem( Keys.meta_key_for( @name, 'indices', 'all' ), key )

          Hash[*fields].each do |field, value|
            if @indices.include?( field )
              DaemonKit.logger.info "\t#{@name}: Removing #{value.inspect} from #{field}"
              remove_value_from_index(key, field, value)
            end
          end

          # @todo deal with custom attributes
        end
      end

      def rename( key, old_key, *fields)
        Snowflake.connection.multi do
          DaemonKit.logger.info "\t#{@name}: Renaming Element key from \"#{old_key}\" to \"#{key}\" for all"
          
          Snowflake.connection.srem( Keys.meta_key_for( @name, 'indices', 'all' ), key )
          Snowflake.connection.sadd( Keys.meta_key_for( @name, 'indices', 'all' ), old_key )

          # @todo deal with custom attributes
        end
      end
      
      private

      def add_value_to_index(key, field, value)
        unless value.respond_to?(:each)
          Snowflake.connection.sadd( Keys.meta_key_for( @name, 'indices', field, value ), key )
        else
          value.each do |v|
            Snowflake.connection.sadd( Keys.meta_key_for( @name, 'indices', field, v ), key )
          end
        end
      end

      def remove_value_from_index(key, field, value)
        unless value.respond_to?(:each)
          Snowflake.connection.srem( Keys.meta_key_for( @name, 'indices', field, value ), key )
        else
          value.each do |v|
            Snowflake.connection.srem( Keys.meta_key_for( @name, 'indices', field, v ), key )
          end
        end
      end
    end
  end # module Indexer
end # module Snowflake