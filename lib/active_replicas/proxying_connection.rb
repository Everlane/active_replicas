module ActiveReplicas
  class ProxyingConnection
    def initialize(connection:, is_primary:, proxy:)
      @connection = connection
      @is_primary = is_primary
      @proxy      = proxy

      # NOTE: This is to support the `database_cleaner gem`:
      #   https://github.com/DatabaseCleaner/database_cleaner/blob/ba3664a/lib/database_cleaner/active_record/deletion.rb#L56
      @config = @connection.instance_variable_get(:@config)
    end

    # Forwards a call to its own connection or back up to the proxy pool's
    # primary connection.
    #
    # role   - Either `:primary` or `:replica`: indicates which database role
    #          is necessary to execute this command.
    # method - Symbol of method to send to a connection.
    def delegate_to(role, method, *args, &block)
      if @is_primary
        @connection.send method, *args, &block
      else
        if role == :primary || @proxy.using_primary?
          # Need to get a primary connection from the proxy pool.
          @proxy.primary_connection.send method, *args, &block
        else
          @connection.send method, *args, &block
        end
      end
    end

    # Helper method to easily use the primary pool from any model:
    #
    #   MyModel.connection.with_primary { ... }
    def with_primary
      @proxy.with_primary { yield }
    end

    # Returns the underlying proxied database connection.
    def proxied_connection
      @connection
    end

    class << self
      # Partially cribbed from:
      #    https://github.com/kickstarter/replica_pools/blob/master/lib/replica_pools/connection_proxy.rb#L20
      def generate_replica_delegations
        Railtie.replica_delegated_methods.each do |method|
          generate_delegation method, :replica
        end
      end

      def generate_primary_delegations
        Railtie.primary_delegated_methods.each do |method|
          generate_delegation method, :primary
        end
      end

      def generate_delegation(method_name, role)
        class_eval <<-END, __FILE__, __LINE__ + 1
          def #{method_name}(*args, &block)
            delegate_to(:#{role}, :#{method_name}, *args, &block)
          end
        END
      end
    end
  end
end
