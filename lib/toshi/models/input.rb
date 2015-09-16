module Toshi
  module Models
    class Input < Sequel::Model

      def previous_output
        @previous_output ||= Output.first(hsh: prev_out, position: index)
      end

      def previous_transaction
        @previous_transaction ||= Transaction.first(hsh: prev_out)
      end

      def transaction
        @transaction ||= Transaction.first(hsh: hsh)
      end

      def transaction_pool
        @transaction_pool ||= Transaction.first(hsh: hsh).pool
      end

      def coinbase?
        prev_out == INPUT_COINBASE_HASH && index == 0xffffffff
      end

      def in_view?(include_memory_pool=true)
        transaction.in_view?(include_memory_pool)
      end

      INPUT_COINBASE_HASH = "00"*32
    end
  end
end
