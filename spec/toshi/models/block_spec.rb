module Toshi
  module Models
    describe Block do

      let(:hsh)       { "f18703c252520781ba2942f1f366c143" }
      let(:prev_block) { "5d87a0ac096e85b8f7e084e89cf70f4f" }
      before do
        @block = Block.new(hsh: hsh, prev_block: prev_block)
      end

      describe "methods to get previous block(s)" do
        # Note that we can't actually create more than 1 previous block because
        # Block has a unique index on 'hsh'
        before { @prev_blocks = [ create_block(hsh: prev_block) ] }

        describe "#previous" do
          it "returns the first previous block" do
            expect(@block.previous).to eq @prev_blocks[0]
          end
        end

        describe "#previous_blocks" do
          it "returns all previous blocks" do
            expect(@block.previous_blocks.to_a).to eq @prev_blocks
          end
        end
      end

      describe "methods to get next block(s)" do
        # Note that we can't actually create more than 1 next block because
        # Block has a unique index on 'hsh'
        before { @next_blocks = [ create_block(prev_block: hsh) ] }

        describe "#next" do
          it "returns the first next block" do
            expect(@block.next).to eq @next_blocks[0]
          end
        end

        describe "#next_blocks" do
          it "returns all next blocks" do
            expect(@block.next_blocks.to_a).to eq @next_blocks
          end
        end
      end

      def create_block(attributes={})
        attributes[:hsh] ||= SecureRandom.hex
        Block.create(attributes)
      end

    end
  end
end
