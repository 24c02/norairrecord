module Norairrecord
  module Util
    class << self
      def all_of(*args)
        "AND(#{args.join(',')})"
      end
      def any_of(*args)
        "OR(#{args.join(',')})"
      end
      def none_of(*args)
        "NOT(#{all_of(*args)})"
      end
      def field_is_any(field, *args)
        any_of(*args.map { |arg| "#{field}='#{arg.gsub(/['"]/, '\\\\\0')}'"})
      end
    end
  end
end