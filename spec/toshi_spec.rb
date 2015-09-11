require "spec_helper"

describe Toshi do

  describe ".env" do
    it "can test equality with == symbols" do
      expect(Toshi.env == :test).to be_truthy
      expect(Toshi.env == :development).to be_falsey
    end

    it "can test equality with boolean methods" do
      expect(Toshi.env.test?).to be_truthy
      expect(Toshi.env.development?).to be_falsey
      expect{Toshi.env.test}.to raise_error(NoMethodError)
    end
  end

end
