require 'spec_helper'
require 'cloud_controller/db_connection_options'

RSpec.describe VCAP::CloudController::DBConnectionOptions do

  describe 'default options' do
    it 'sets the sql_mode as expected' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new

      expect(db_connection_options.sql_mode).to eq([:strict_trans_tables, :strict_all_tables, :no_zero_in_date])
    end
  end

  describe 'when the Cloud Controller config specifies generic options' do
    it 'sets the max connections' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new(
        max_connections: 3000
      )

      expect(db_connection_options.max_connections).to eq(3000)
    end

    it 'sets the pool timeout' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new(
        pool_timeout: 2000
      )

      expect(db_connection_options.pool_timeout).to eq(2000)
    end

    it 'sets the read timeout' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new(
        read_timeout: 1000
      )

      expect(db_connection_options.read_timeout).to eq(1000)
    end

    it 'sets the db log level' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new(
        log_level: 'super-high'
      )

      expect(db_connection_options.log_level).to eq('super-high')
    end

    it 'sets the option for logging db queries' do
      db_connection_options = VCAP::CloudController::DBConnectionOptions.new(
        log_db_queries: true
      )

      expect(db_connection_options.log_db_queries).to eq(true)
    end
  end

  describe '.build' do

    it 'raises if the database_scheme is unsupported' do
      expect{
        VCAP::CloudController::DBConnectionOptions.build(database: 'foo')
      }.to raise_error(VCAP::CloudController::DBConnectionOptions::UnknownSchemeError)
    end

  end

  describe 'when the Cloud Controller Config specifies MySQL' do
    let(:ssl_verify_hostname) { true }
    let(:mysql_config) do
      VCAP::CloudController::DBConnectionOptions.build(
        database: 'mysql2://cloud_controller:p4ssw0rd@sql-db.service.cf.internal:3306/cloud_controller',
        database_parts: {
          adapter: 'mysql2',
          host: 'sql-db.service.cf.internal',
          port: 3306,
          user: 'cloud_controller',
          password: 'p4ssw0rd',
          database: 'cloud_controller'},
        ca_cert_path: '/path/to/db_ca.crt',
        ssl_verify_hostname: ssl_verify_hostname
      )
    end

    it 'returns the correct class' do
      expect(mysql_config).to be_a(VCAP::CloudController::MySQLDBConnectionOptions)
    end

    it 'the charset should be set' do
      expect(mysql_config.charset).to eq('utf8')
    end

    it 'should set the timezone via a Proc' do
      connection = double('connection', query: '')
      mysql_config.after_connect.call(connection)
      expect(connection).to have_received(:query).with("SET time_zone = '+0:00'")
    end

    describe 'when the CA cert path is set' do
      it 'sets the ssl root cert' do
        expect(mysql_config.sslca).to eq('/path/to/db_ca.crt')
      end

      describe 'sslmode' do
        context 'when ssl_verify_hostname is truthy' do
          let(:ssl_verify_hostname) { true }

          it 'sets the ssl verify options' do
            expect(mysql_config.sslmode).to eq(:verify_identity)
            expect(mysql_config.sslverify).to eq(true)
          end
        end
        context 'when ssl_verify_hostname is falsey' do
          let(:ssl_verify_hostname) { false }

          it 'sets the sslmode to :verify-ca' do
            expect(mysql_config.sslmode).to eq(:verify_ca)
          end
        end
      end
    end
  end

  describe 'when the Cloud Controller Config specifies Postgres' do
    let(:ssl_verify_hostname) { true }
    let(:postgres_config_options) do
      VCAP::CloudController::DBConnectionOptions.build(
        database: 'postgres://cloud_controller:p4ssw0rd@sql-db.service.cf.internal:5524/cloud_controller',
        database_parts: {
          adapter: 'postgres',
          host: 'sql-db.service.cf.internal',
          port: 5524,
          user: 'cloud_controller',
          password: 'p4ssw0rd',
          database: 'cloud_controller'},
        ca_cert_path: '/path/to/db_ca.crt',
        ssl_verify_hostname: ssl_verify_hostname
      )
    end

    it 'returns the correct class' do
      expect(postgres_config_options).to be_a(VCAP::CloudController::PostgresDBConnectionOptions)
    end

    it 'should set the timezone via a Proc' do
      connection = double('connection', exec: '')
      postgres_config_options.after_connect.call(connection)
      expect(connection).to have_received(:exec).with("SET time zone 'UTC'")
    end

    describe 'when the CA cert path is set' do
      it 'sets the ssl root cert' do
        expect(postgres_config_options.sslrootcert).to eq('/path/to/db_ca.crt')
      end

      describe 'sslmode' do
        context 'when ssl_verify_hostname is truthy' do
          let(:ssl_verify_hostname) { true }

          it 'sets the sslmode to "verify-full"' do
            expect(postgres_config_options.sslmode).to eq('verify-full')
          end
        end
        context 'when ssl_verify_hostname is falsey' do
          let(:ssl_verify_hostname) { false }

          it 'sets the sslmode to "verify-ca"' do
            expect(postgres_config_options.sslmode).to eq('verify-ca')
          end
        end
      end
    end
  end
end

=begin
db: &db
  database: "postgres://cloud_controller:jgkOPa1pDLqCMLAceiYHM1Ag3Fru7L@sql-db.service.cf.internal:5524/cloud_controller"
  database_parts:
    adapter: postgres
    host: sql-db.service.cf.internal
    port: 5524
    user: cloud_controller
    password: jgkOPa1pDLqCMLAceiYHM1Ag3Fru7L
    database: cloud_controller
  max_connections: 25
  pool_timeout: 10
  log_level: "debug2"
  log_db_queries: false
  ssl_verify_hostname:
  read_timeout: 3600
  connection_validation_timeout: 3600

  ca_cert_path: "/var/vcap/jobs/cloud_controller_ng/config/certs/db_ca.crt"
=end