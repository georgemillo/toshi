require "toshi/web/base"

module Toshi
  module Web

    class Api < Toshi::Web::Base
      # Allow cross-origin requests
      before do
        headers 'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => ['OPTIONS', 'GET', 'POST'],
                'Access-Control-Allow-Headers' => 'Content-Type'
      end
      set :protection, false
      options '/*' do
        200
      end

      helpers do
        def format
          fmt = params[:format].to_s
          fmt = 'json' if fmt == ''
          case fmt
          when 'hex' then content_type 'text/plain'
          when 'bin' then content_type 'application/octet-stream'
          when 'json' then content_type 'application/json'
          when 'rss' then content_type 'application/rss+xml'
          end
          fmt
        end

        def json(obj)
          options = {:space => ''}
          JSON.pretty_generate(obj, options)
        end
      end

      ####
      ## /blocks
      ####

      # get collection of blocks
      get '/blocks.?:format?' do
        @blocks = Toshi::Models::Block.limit(50).order(Sequel.desc(:id))

        case format
        when 'json'
          json @blocks.map(&:to_hash)
        when 'rss'
          builder :blocks_rss
        else
          raise InvalidFormatError
        end
      end

      # get latest block or search by hash or height
      get '/blocks/:hash.?:format?' do
        @block = load_block
        format_data(@block, format)
      end

      # get block transactions
      get '/blocks/:hash/transactions.?:format?' do
        @block = load_block

        case format
        when 'json'
          json(@block.to_hash({show_txs: true, offset: params[:offset], limit: params[:limit]}))
        else
          raise InvalidFormatError
        end
      end

      ####
      ## /transactions
      ####

      # submit new transaction to network
      post '/transactions.?:format?' do
        begin
          json = JSON.parse(request.body.read)
          ptx = Bitcoin::P::Tx.new([json['hex']].pack("H*"))
        rescue
          return { error: 'malformed transaction' }.to_json
        end

        if Toshi::Models::RawTransaction.find(hsh: ptx.hash) ||
            Toshi::Models::UnconfirmedRawTransaction.find(hsh: ptx.hash)
          return { error: 'transaction already received' }.to_json
        end

        begin
          processor = Toshi::Processor.new
          processor.process_transaction(ptx, raise_error=true)
        rescue Toshi::Processor::ValidationError => ex
          return { error: ex.message }.to_json
        end

        { hash: ptx.hash }.to_json
      end

      get '/transactions/unconfirmed' do
        case format
        when 'json'
          options = {offset: params[:offset], limit: params[:limit]}
          Toshi::Utils.sanitize_options(options)
          mempool = Toshi::Models::UnconfirmedTransaction.mempool.offset(options[:offset]).limit(options[:limit])
          mempool = Toshi::Models::UnconfirmedTransaction.to_hash_collection(mempool)
          json(mempool)
        else
          raise InvalidFormatError
        end
      end

      get '/transactions/:hash.?:format?' do
        @tx = (params[:hash].bytesize == 64 && Toshi::Models::Transaction.find(hsh: params[:hash]))
        @tx ||= (params[:hash].bytesize == 64 && Toshi::Models::UnconfirmedTransaction.find(hsh: params[:hash]))
        raise NotFoundError unless @tx

        format_data(@tx, format)
      end

      ####
      ## /addresses
      ####

      get '/addresses/:address.?:format?' do
        address = Toshi::Models::Address.find(address: params[:address])
        address = Toshi::Models::UnconfirmedAddress.find(address: params[:address]) unless address
        raise NotFoundError unless address

        case format
        when 'json';
          json(address.to_hash)
        else
          raise InvalidFormatError
        end
      end

      get '/addresses/:address/transactions.?:format?' do
        address = Toshi::Models::Address.find(address: params[:address])
        address = Toshi::Models::UnconfirmedAddress.find(address: params[:address]) unless address
        raise NotFoundError unless address

        case format
        when 'json'
          json address.to_hash(options={show_txs: true, offset: params[:offset], limit: params[:limit]})
        else
          raise InvalidFormatError
        end
      end

      get '/addresses/:address/unspent_outputs.?:format?' do
        @address = Toshi::Models::Address.find(address: params[:address])
        raise NotFoundError unless @address

        case format
        when 'json'
          options = {offset: params[:offset], limit: params[:limit]}
          Toshi::Utils.sanitize_options(options)

          unspent_outputs = @address.unspent_outputs.offset(options[:offset])
            .limit(options[:limit]).order(:unspent_outputs__amount)

          unspent_outputs = Toshi::Models::Output.to_hash_collection(unspent_outputs)
          json(unspent_outputs)
        else
          raise InvalidFormatError
        end
      end

      get '/addresses/:address/balance_at.?:format?' do
        @address = Toshi::Models::Address.find(address: params[:address])
        raise NotFoundError unless @address

        time = params[:time]
        time = Time.now if !time || time.to_i == 0
        block = Toshi::Models::Block.from_time(time.to_i)

        case format
        when 'json'
          {
            balance: @address.balance_at(block.height),
            address: @address.address,
            block_height: block.height,
            block_time: block.time
          }.to_json
        else
          raise InvalidFormatError
        end
      end

      ####
      ## /search
      ####
      get '/search/:query.?:format?' do
        # block || tx
        if params[:query].bytesize == 64
          if @block = Toshi::Models::Block.find(hsh: params[:query], branch: 0)
            path = 'blocks'
            hash = @block.hsh
          else
            if @transaction = Toshi::Models::Transaction.find(hsh: params[:query])
              path = 'transactions'
              hash = @transaction.hsh
            end
          end

        # block height
        elsif /\A[0-9]+\Z/.match(params[:query])
          if @block = Toshi::Models::Block.find(height: params[:query].to_i, branch: 0)
            path = 'blocks'
            hash = @block.hsh
          end

        # address hash
        elsif Bitcoin.valid_address?(params[:query])
          if @address = Toshi::Models::Address.find(address: params[:query])
            path = 'addresses'
            hash = @address.address
          end
        end

        raise NotFoundError unless (path && hash)

        case format
        when 'json'
          json({
            path: path,
            hash: hash
          })
        else
          raise InvalidFormatError
        end
      end

      ####
      ## /toshi
      ####

      get '/toshi.?:format?' do
        hash = {
          peers: {
            available: Toshi::Models::Peer.count,
            connected: Toshi::Models::Peer.connected.count,
            info: Toshi::Models::Peer.connected.map{|peer| peer.to_hash}
          },
          database: {
            size: Toshi::Utils.database_size
          },
          transactions: {
            count: Toshi::Models::Transaction.total_count,
            unconfirmed_count: Toshi::Models::UnconfirmedTransaction.total_count
          },
          blocks: {
            main_count: Toshi::Models::Block.main_branch.count(),
            side_count: Toshi::Models::Block.side_branch.count(),
            orphan_count: Toshi::Models::Block.orphan_branch.count(),
          },
          status: Toshi::Utils.status
        }

        case format
        when 'json'
          json(hash)
        else
          raise InvalidFormatError
        end
      end


      private

      def load_block
        block = if hash == 'latest'
                  Models::Block.head
                elsif hash =~ /\A\d#{64}\z/
                  Models::Block.find(height: params[:hash], branch: 0)
                else
                  Models::Block.find(hsh: params[:hash])
                end
        block || raise(NotFoundError)
      end

      def format_data(data, format)
        case format
        when 'json' then json(data.to_hash)
        when 'hex'  then data.raw.payload.unpack("H*")[0]
        when 'bin'  then data.raw.payload
        else raise InvalidFormatError
        end
      end

    end
  end
end
