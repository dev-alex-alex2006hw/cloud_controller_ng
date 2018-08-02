require 'cloud_controller/deployment_updater/updater'
require 'locket/lock_worker'
require 'locket/lock_runner'

module VCAP::CloudController
  module DeploymentUpdater
    class Scheduler
      def self.start
        config = CloudController::DependencyLocator.instance.config
        update_frequency = config.get(:deployment_updater, :update_frequency_in_seconds)
        logger = Steno.logger('cc.deployment_updater.scheduler')

        lock_runner = Locket::LockRunner.new(
          key: config.get(:deployment_updater, :lock_key),
          owner: config.get(:deployment_updater, :lock_owner),
          host: config.get(:locket, :host),
          port: config.get(:locket, :port),
          client_ca_path: config.get(:locket, :ca_file),
          client_key_path: config.get(:locket, :key_file),
          client_cert_path: config.get(:locket, :cert_file),
        )

        lock_worker = Locket::LockWorker.new(lock_runner)

        lock_worker.acquire_lock_and do
          t1 = Time.now
          Updater.update
          update_duration = Time.now - t1
          logger.info("Update loop took #{Time.now - t1}s")
          if update_duration < update_frequency
            logger.info("Sleeping #{update_frequency - update_duration}s")
            sleep(update_frequency - update_duration)
          else
            logger.info('Not Sleeping')
          end
        end
      end
    end
  end
end
