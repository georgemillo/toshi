module Toshi
  class Env < Struct.new(:name)

    def ==(other)
      other.respond_to?(:name) ? name == other.name : name == other
    end

    def to_s
      name.to_s
    end

    private

    def respond_to_missing?(method_name, include_private = false)
      method_name[-1] == '?'
    end

    def method_missing(method_name, *arguments)
      method_name[-1] == '?' ?  to_s == method_name[0..-2] : super
    end

  end
end
