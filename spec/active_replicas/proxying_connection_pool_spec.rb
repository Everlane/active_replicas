require 'spec_helper'

describe ActiveReplicas::ProxyingConnectionPool do
  subject { ActiveReplicas::ProxyingConnectionPool }

  before do
    @primary_pool = double 'primary connection pool'
    @replica_pool = double 'replica connection pool'
    @handler = double 'handler', primary_pool: @primary_pool,
                                 replica_pools: { default0: @replica_pool }

    @subject = subject.new @handler
  end

  describe '#connection' do
    it 'returns a connection from the current pool' do
      connection = double 'connection'
      expect(@replica_pool).to receive(:connection).and_return(connection)
      expect(@subject.connection).to_not be_nil
    end

    it 'returns a proxied connection' do
      connection = double 'connection'
      @replica_pool.stub connection: connection

      proxying_connection = @subject.connection
      expect(proxying_connection).to be_a ActiveReplicas::ProxyingConnection
      expect(proxying_connection.proxied_connection).to eq connection
    end
  end

  describe '#current_pool' do
    it 'defaults to the next replica pool' do
      expect(@subject.current_pool).to eq @replica_pool
    end

    it 'respects overrides' do
      @primary_pool.stub connection: double('connection')

      @subject.with_primary do
        expect(@subject.current_pool).to eq @primary_pool
      end
    end
  end

  describe '#with_primary' do
    before do
      @replica_connection = double 'replica connection'
      @replica_pool.stub connection: @replica_connection

      @primary_connection = double 'primary connection'
      @primary_pool.stub connection: @primary_connection
    end

    it 'switches to the primary pool' do
      expect(@subject.current_pool).to eq @replica_pool

      @subject.with_primary do
        expect(@subject.current_pool).to eq @primary_pool
      end
    end

    it 'restores the current pool afterwards' do
      expect(@subject.current_pool).to eq @replica_pool

      @subject.with_primary do
        nil # pass
      end

      expect(@subject.current_pool).to eq @replica_pool
    end
  end
end
