require 'rubygems' # For Gem::Version

module Norairrecord
  class Table
    BATCH_SIZE = 10

    class << self
      attr_writer :api_key, :base_key, :table_name

      include Norairrecord::Util

      def base_key
        @base_key || (superclass < Table ? superclass.base_key : nil)
      end

      def table_name
        @table_name || (superclass < Table ? superclass.table_name : nil)
      end


      # finds the actual parent class of a (possibly) subtype class
      def responsible_class
        if @base_key
          self.class
        else
          superclass < Table ? superclass.responsible_class : nil
        end
      end

      def client
        @@clients ||= {}
        @@clients[api_key] ||= Client.new(api_key)
      end

      def api_key
        defined?(@api_key) ? @api_key : Norairrecord.api_key
      end

      def has_many(method_name, options)
        define_method(method_name.to_sym) do |where: nil, sort: nil|
          # Get association ids in reverse order, because Airtable's UI and API
          # sort associations in opposite directions. We want to match the UI.
          ids = (self[options.fetch(:column)] || []).reverse
          table = Kernel.const_get(options.fetch(:class))
          return table.find_many(ids, sort:, where:) unless options[:single]

          (id = ids.first) ? table.find(id) : nil
        end

        define_method("#{method_name}=".to_sym) do |value|
          __set_field(options.fetch(:column), Array(value).map(&:id).reverse)
        end
      end

      def belongs_to(method_name, options)
        has_many(method_name, options.merge(single: true))
      end

      alias has_one belongs_to

      def has_subtypes(column, mapping, strict: false)
        @subtype_column = column
        @subtype_mapping = mapping
        @subtype_strict = strict
      end

      def find(id)
        response = client.connection.get("v0/#{base_key}/#{client.escape(table_name)}/#{id}")
        parsed_response = client.parse(response.body)

        if response.success?
          self.new_with_subtype(parsed_response["fields"], id: id, created_at: parsed_response["createdTime"])
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def find_many(ids, where: nil, sort: nil)
        return [] if ids.empty?

        formula = any_of(ids.map { |id| "RECORD_ID() = '#{id}'" })
        formula = all_of(formula, where) if where
        records(filter: formula, sort:).sort_by { |record| or_args.index(record.id) }
      end

      def _update(id, update_hash = {}, options = {})
        # To avoid trying to update computed fields we *always* use PATCH
        body = {
          fields: update_hash,
          **options
        }.to_json

        response = client.connection.patch("v0/#{base_key}/#{client.escape(table_name)}/#{id}", body, { 'Content-Type' => 'application/json' })
        parsed_response = client.parse(response.body)

        if response.success?
          parsed_response["fields"]
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def _new(*args, **kwargs)
        new(*args, **kwargs)
      end

      def _create(fields, options = {})
        _new(fields).tap { |record| record._save(options) }
      end

      alias update _update
      alias create _create

      def new_with_subtype(fields, id:, created_at:)
        if @subtype_column
          clazz = self
          st = @subtype_mapping[fields[@subtype_column]]
          raise Norairrecord::UnknownTypeError, "#{fields[@subtype_column]}?????" if @subtype_strict && st.nil?
          clazz = Kernel.const_get(st) if st
          clazz._new(fields, id:, created_at:)
        else
          self._new(fields, id: id, created_at: created_at)
        end
      end

      def records(filter: nil, sort: nil, view: nil, offset: nil, paginate: true, fields: nil, max_records: nil, page_size: nil)
        options = {}
        options[:filterByFormula] = filter if filter

        if sort
          options[:sort] = sort.map { |field, direction|
            { field: field.to_s, direction: direction }
          }
        end

        options[:view] = view if view
        options[:offset] = offset if offset
        options[:fields] = fields if fields
        options[:maxRecords] = max_records if max_records
        options[:pageSize] = page_size if page_size

        path = "v0/#{base_key}/#{client.escape(table_name)}/listRecords"
        response = client.connection.post(path, options.to_json, { 'Content-Type' => 'application/json' })
        parsed_response = client.parse(response.body)

        if response.success?
          records = map_new parsed_response["records"]

          if paginate && parsed_response["offset"]
            records.concat(records(
                             filter: filter,
                             sort: sort,
                             view: view,
                             paginate: paginate,
                             fields: fields,
                             offset: parsed_response["offset"],
                             max_records: max_records,
                             page_size: page_size,
                           ))
          end

          records
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def first(options = {})
        records(**options.merge(max_records: 1)).first
      end

      def first_where(filter, options = {})
        first(options.merge(filter:))
      end

      def where(filter, options = {})
        records(**options.merge(filter:))
      end

      def map_new(arr)
        arr.map do |record|
          self.new_with_subtype(record["fields"], id: record["id"], created_at: record["createdTime"])
        end
      end

      def batch_update(recs, options = {})
        res = []
        recs.each_slice(BATCH_SIZE) do |chunk|
          body = {
            records: chunk.map do |record|
              {
                fields: record.update_hash,
                id: record.id,
              }
            end,
            **options
          }.to_json

          response = client.connection.patch("v0/#{base_key}/#{client.escape(table_name)}", body, { 'Content-Type' => 'application/json' })
          parsed_response = client.parse(response.body)
          if response.success?
            res.concat(parsed_response["records"])
          else
            client.handle_error(response.status, parsed_response)
          end
        end
        map_new res
      end

      def batch_upsert(recs, merge_fields, options = {}, include_ids: nil, hydrate: false)
        merge_fields = Array(merge_fields) # allows passing in a single field

        created, updated, records = [], [], []

        recs.each_slice(BATCH_SIZE) do |chunk|
          body = {
            records: chunk.map { |rec| { fields: rec.fields, id: (include_ids ? rec.id : nil) }.compact },
            **options,
            performUpsert: { fieldsToMergeOn: merge_fields }
          }.to_json

          response = client.connection.patch("v0/#{base_key}/#{client.escape(table_name)}", body, { 'Content-Type' => 'application/json' })
          parsed_response = response.success? ? client.parse(response.body) : client.handle_error(response.status, client.parse(response.body))

          if response.success?
            created.concat(parsed_response.fetch('createdRecords', []))
            updated.concat(parsed_response.fetch('updatedRecords', []))
            records.concat(parsed_response.fetch('records', []))
          else
            client.handle_error(response.status, parsed_response)
          end
        end

        if hydrate && records.any?
          record_hash = records.map { |record| [record["id"], self.new_with_subtype(record["fields"], id: record["id"], created_at: record["createdTime"])] }.to_h

          created.map! { |id| record_hash[id] }.compact!
          updated.map! { |id| record_hash[id] }.compact!
          records = record_hash.values
        end

        { created:, updated:, records: }
      end

      def batch_create(recs, options = {})
        records = []
        recs.each_slice(BATCH_SIZE) do |chunk|
          body = {
            records: chunk.map { |record| { fields: record.serializable_fields } },
            **options
          }.to_json

          response = client.connection.post("v0/#{base_key}/#{client.escape(table_name)}", body, { 'Content-Type' => 'application/json' })
          parsed_response = client.parse(response.body)

          if response.success?
            records.concat(parsed_response["records"])
          else
            client.handle_error(response.status, parsed_response)
          end
        end
        map_new records
      end

      def upsert(fields, merge_fields, options = {})
        record = batch_upsert([self._new(fields)], merge_fields, options)&.dig(:records, 0)
        record ? _new(record) : nil
      end

      def batch_save(records)
        res = []
        to_be_created, to_be_updated = records.partition &:new_record?
        res.concat(batch_create(to_be_created))
        res.concat(batch_update(to_be_updated))
      end

      alias all records
    end

    attr_reader :fields, :id, :created_at, :updated_keys

    # This is an awkward definition for Ruby 3 to remain backwards compatible.
    # It's easier to read by reading the 2.x definition below.
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0.0")
      def initialize(*one, **two)
        @id = one.first && two.delete(:id)
        self.created_at = one.first && two.delete(:created_at)
        self.fields = one.first || two
      end
    else
      def initialize(fields, id: nil, created_at: nil)
        @id = id
        self.created_at = created_at
        self.fields = fields
      end
    end

    def new_record?
      !id
    end

    def [](key)
      validate_key(key)
      fields[key]
    end

    def __set_field(key, value)
      validate_key(key)
      return if fields[key] == value # no-op

      @updated_keys << key
      fields[key] = value
    end

    alias []= __set_field

    def patch(updates = {}, options = {})
      updates.reject! { |key, value| @fields[key] == value }
      return @fields if updates.empty? # don't hit AT if we don't have real changes
      @fields.merge!(self.class._update(self.id, updates, options).reject { |key, _| updated_keys.include?(key) })
    end

    def _create(options = {})
      raise Error, "Record already exists (record has an id)" unless new_record?

      body = {
        fields: serializable_fields,
        **options
      }.to_json

      response = client.connection.post("v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}", body, { 'Content-Type' => 'application/json' })
      parsed_response = client.parse(response.body)

      if response.success?
        @id = parsed_response["id"]
        self.created_at = parsed_response["createdTime"]
        self.fields = parsed_response["fields"]
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def _save(options = {})
      return _create(options) if new_record?
      return true if @updated_keys.empty?
      self.fields = self.class._update(self.id, self.update_hash, options)
    end

    alias create _create
    alias save _save

    def update_hash
      Hash[@updated_keys.map { |key|
        [key, fields[key]]
      }]
    end

    def destroy
      raise Error, "Unable to destroy new record" if new_record?

      response = client.connection.delete("v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}/#{self.id}")
      parsed_response = client.parse(response.body)

      if response.success?
        true
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def serializable_fields
      fields
    end

    def comment(text)
      response = client.connection.post("v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}/#{self.id}/comments", { text: }.to_json, { 'Content-Type' => 'application/json' })
      parsed_response = client.parse(response.body)

      if response.success?
        parsed_response['id']
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def airtable_url
      "https://airtable.com/#{self.class.base_key}/#{self.class.table_name}/#{self.id}"
    end

    def ==(other)
      self.class == other.class &&
        serializable_fields == other.serializable_fields
    end

    alias eql? ==

    def hash
      serializable_fields.hash
    end

    # ahahahahaha
    def transaction(&block)
      txn_updates = {}

      singleton_class.define_method(:original_setter, method(:__set_field))

      define_singleton_method(:__set_field) do |key, value|
        txn_updates[key] = value
      end

      singleton_class.send(:alias_method, :[]=, :__set_field)

      begin
        result = yield self
        @updated_keys -= txn_updates.keys
        if new_record?
          @fields.merge!(txn_updates)
          _save
        else
          self.patch(txn_updates)
        end
      rescue => e
        raise
      ensure
        singleton_class.define_method(:[]=, method(:original_setter))
        singleton_class.remove_method(:original_setter)
      end
      result
    end

    protected

    def fields=(fields)
      @updated_keys = []
      @fields = fields
    end

    def created_at=(created_at)
      return unless created_at

      @created_at = Time.parse(created_at)
    end

    def client
      self.class.client
    end

    def validate_key(key)
      return true unless key.is_a?(Symbol)

      raise(Error, [
        "Airrecord 1.0 dropped support for Symbols as field names.",
        "Please use the raw field name, a String, instead.",
        "You might try: record['#{key.to_s.tr('_', ' ')}']"
      ].join("\n"))
    end
  end

  def self.table(api_key, base_key, table_name)
    Class.new(Table) do |klass|
      klass.table_name = table_name
      klass.api_key = api_key
      klass.base_key = base_key
    end
  end
end
