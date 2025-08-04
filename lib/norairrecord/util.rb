module Norairrecord
  module Util
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
      any_of(*args.map { |arg| "#{field}='#{sanitize(arg)}'" })
    end

    def sanitize(arg)
      arg.gsub(/['"]/, '\\\\\0')
    end

    def mass_sanitize(*args)
      args.map { |arg| sanitize(arg) }
    end

    module_function :all_of, :any_of, :none_of, :field_is_any, :sanitize, :mass_sanitize
  end
end
