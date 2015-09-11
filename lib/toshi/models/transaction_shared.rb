module Toshi
  module Models
    module TransactionShared

      def self.included(base)
        base.extend ClassMethods
      end

      def bitcoin_tx
        Bitcoin::P::Tx.new(raw.payload)
      end

      def inputs
        input_class.where(hsh: hsh).order(:position)
      end

      def is_coinbase?
        inputs_count == 1 && inputs.first.coinbase?
      end

      def outputs
        output_class.where(hsh: hsh).order(:position)
      end

      def pool_name
        self.class::POOL_TO_NAME_TABLE[pool] || "unknown"
      end

      def raw
        raw_class.find(hsh: hsh)
      end

      def to_hash(options = {})
        options[:show_block_info] ||= true
        self.class.to_hash_collection([self], options).first
      end

      def to_json(options={})
        to_hash(options).to_json
      end

      module ClassMethods
        def from_hsh(hash)
          find(hsh: hash)
        end

        # This is much faster than a count(*) on the table.
        # See: https://wiki.postgresql.org/wiki/Slow_Counting
        def total_count
          Toshi.db.fetch(
            "SELECT reltuples AS total FROM pg_class "\
            "WHERE relname = '#{table_name}'"
          ).first[:total].to_i
        end
      end
    end
  end
end
