require "sidekiq"

module Toshi
  module Workers
    class TransactionWorker
      include Sidekiq::Worker

      sidekiq_options queue: :transactions, :retry => true

      def perform(tx_hash, _sender)
        return if Toshi::Models::Transaction.first(hsh: tx_hash)
        return if Toshi::Models::UnconfirmedTransaction.first(hsh: tx_hash)
        tx = Toshi::Models::UnconfirmedRawTransaction.first(hsh: tx_hash)
        return unless tx

        begin
          result = processor.process_transaction(tx.bitcoin_tx, raise_error=true)
        rescue Toshi::Processor::ValidationError => ex
          # we want anything else to blow up
          logger.warn{ ex.message }
        end

        logger.info{ result }
      end

      def processor
        @@processor ||= Toshi::Processor.new
      end
    end
  end
end
