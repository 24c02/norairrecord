require 'spec_helper'

RSpec.describe Norairrecord::Table do
  let(:test_table_class) do
    Class.new(Norairrecord::Table) do
      self.base_key = 'test_base'
      self.table_name = 'Test Table'
      self.api_key = 'test_key'
    end
  end

  describe 'initialization' do
    it 'creates a new record with fields' do
      record = test_table_class.new('Name' => 'Test', 'Value' => 42)
      expect(record['Name']).to eq('Test')
      expect(record['Value']).to eq(42)
    end

    it 'creates a new record with id and created_at using keyword args' do
      time = Time.now.iso8601
      record = test_table_class.new({ 'Name' => 'Test' }, id: 'rec123', created_at: time)
      expect(record.id).to eq('rec123')
      expect(record.created_at).to be_a(Time)
    end

    it 'initializes with empty updated_keys' do
      record = test_table_class.new('Name' => 'Test')
      expect(record.updated_keys).to eq([])
    end
  end

  describe '#new_record?' do
    it 'returns true when id is nil' do
      record = test_table_class.new('Name' => 'Test')
      expect(record).to be_new_record
    end

    it 'returns false when id is present' do
      record = test_table_class.new({ 'Name' => 'Test' }, id: 'rec123', created_at: Time.now.iso8601)
      expect(record).not_to be_new_record
    end
  end

  describe '#[]' do
    it 'retrieves field values' do
      record = test_table_class.new('Name' => 'Test', 'Count' => 5)
      expect(record['Name']).to eq('Test')
      expect(record['Count']).to eq(5)
    end

    it 'raises error for symbol keys' do
      record = test_table_class.new('Name' => 'Test')
      expect { record[:Name] }.to raise_error(Norairrecord::Error, /Symbols as field names/)
    end
  end

  describe '#[]=' do
    it 'sets field values' do
      record = test_table_class.new('Name' => 'Original')
      record['Name'] = 'Updated'
      expect(record['Name']).to eq('Updated')
    end

    it 'tracks updated keys' do
      record = test_table_class.new('Name' => 'Original', 'Status' => 'Active')
      record['Name'] = 'Updated'
      record['Status'] = 'Inactive'
      expect(record.updated_keys).to contain_exactly('Name', 'Status')
    end

    it 'does not track unchanged values' do
      record = test_table_class.new('Name' => 'Same')
      record['Name'] = 'Same'
      expect(record.updated_keys).to be_empty
    end

    it 'raises error for symbol keys' do
      record = test_table_class.new('Name' => 'Test')
      expect { record[:Name] = 'Value' }.to raise_error(Norairrecord::Error, /Symbols as field names/)
    end
  end

  describe '#update_hash' do
    it 'returns hash of updated fields' do
      record = test_table_class.new('Name' => 'Original', 'Status' => 'Active', 'Count' => 0)
      record['Name'] = 'Updated'
      record['Count'] = 5
      
      expect(record.update_hash).to eq('Name' => 'Updated', 'Count' => 5)
    end
  end

  describe '#serializable_fields' do
    it 'returns all fields' do
      fields = { 'Name' => 'Test', 'Value' => 42 }
      record = test_table_class.new(fields)
      expect(record.serializable_fields).to eq(fields)
    end
  end

  describe '#==' do
    it 'returns true for records with same class and fields' do
      record1 = test_table_class.new('Name' => 'Test', 'Value' => 42)
      record2 = test_table_class.new('Name' => 'Test', 'Value' => 42)
      expect(record1).to eq(record2)
    end

    it 'returns false for records with different fields' do
      record1 = test_table_class.new('Name' => 'Test1')
      record2 = test_table_class.new('Name' => 'Test2')
      expect(record1).not_to eq(record2)
    end

    it 'returns false for records of different classes' do
      other_class = Class.new(Norairrecord::Table)
      record1 = test_table_class.new('Name' => 'Test')
      record2 = other_class.new('Name' => 'Test')
      expect(record1).not_to eq(record2)
    end
  end

  describe '#hash' do
    it 'returns hash based on fields' do
      record1 = test_table_class.new('Name' => 'Test', 'Value' => 42)
      record2 = test_table_class.new('Name' => 'Test', 'Value' => 42)
      expect(record1.hash).to eq(record2.hash)
    end
  end

  describe '.has_many' do
    let(:association_class) do
      Class.new(Norairrecord::Table) do
        self.base_key = 'test_base'
        self.table_name = 'Items'
        self.api_key = 'test_key'
      end
    end

    before do
      stub_const('AssociatedItem', association_class)
      test_table_class.has_many(:items, class: 'AssociatedItem', column: 'Items')
    end

    it 'defines a getter method' do
      record = test_table_class.new('Items' => [])
      expect(record).to respond_to(:items)
    end

    it 'defines a setter method' do
      record = test_table_class.new('Items' => [])
      expect(record).to respond_to(:items=)
    end

    it 'setter reverses association ids' do
      record = test_table_class.new('Items' => [])
      item1 = association_class.new('Name' => 'Item1')
      item1.instance_variable_set(:@id, 'rec1')
      item2 = association_class.new('Name' => 'Item2')
      item2.instance_variable_set(:@id, 'rec2')
      
      record.items = [item1, item2]
      expect(record['Items']).to eq(['rec2', 'rec1'])
    end
  end

  describe '.belongs_to' do
    let(:parent_class) do
      Class.new(Norairrecord::Table) do
        self.base_key = 'test_base'
        self.table_name = 'Parents'
        self.api_key = 'test_key'
      end
    end

    before do
      stub_const('Parent', parent_class)
      test_table_class.belongs_to(:parent, class: 'Parent', column: 'Parent')
    end

    it 'defines a getter method' do
      record = test_table_class.new('Parent' => [])
      expect(record).to respond_to(:parent)
    end

    it 'defines a setter method' do
      record = test_table_class.new('Parent' => [])
      expect(record).to respond_to(:parent=)
    end
  end

  describe '.has_one' do
    it 'is aliased to belongs_to' do
      expect(test_table_class.method(:has_one)).to eq(test_table_class.method(:belongs_to))
    end
  end

  describe '.has_subtypes' do
    it 'sets subtype configuration' do
      mapping = { 'TypeA' => 'ClassA', 'TypeB' => 'ClassB' }
      test_table_class.has_subtypes('Type', mapping, strict: true)
      
      expect(test_table_class.instance_variable_get(:@subtype_column)).to eq('Type')
      expect(test_table_class.instance_variable_get(:@subtype_mapping)).to eq(mapping)
      expect(test_table_class.instance_variable_get(:@subtype_strict)).to be true
    end
  end

  describe '.api_key' do
    it 'returns class api_key if set' do
      expect(test_table_class.api_key).to eq('test_key')
    end

    it 'returns global api_key if class api_key not set' do
      Norairrecord.api_key = 'global_key'
      new_class = Class.new(Norairrecord::Table)
      expect(new_class.api_key).to eq('global_key')
    ensure
      Norairrecord.api_key = nil
    end
  end

  describe '.base_key' do
    it 'returns base_key' do
      expect(test_table_class.base_key).to eq('test_base')
    end

    it 'inherits from superclass if not set' do
      subclass = Class.new(test_table_class)
      expect(subclass.base_key).to eq('test_base')
    end
  end

  describe '.table_name' do
    it 'returns table_name' do
      expect(test_table_class.table_name).to eq('Test Table')
    end

    it 'inherits from superclass if not set' do
      subclass = Class.new(test_table_class)
      expect(subclass.table_name).to eq('Test Table')
    end
  end

  describe '.client' do
    it 'creates and caches a client per api_key' do
      client1 = test_table_class.client
      client2 = test_table_class.client
      expect(client1).to be_a(Norairrecord::Client)
      expect(client1).to be(client2)
    end
  end

  describe '#client' do
    it 'delegates to class method' do
      record = test_table_class.new('Name' => 'Test')
      expect(record.send(:client)).to eq(test_table_class.client)
    end
  end

  describe '#airtable_url' do
    it 'generates correct URL' do
      record = test_table_class.new({ 'Name' => 'Test' }, id: 'rec123', created_at: Time.now.iso8601)
      expect(record.airtable_url).to eq('https://airtable.com/test_base/Test Table/rec123')
    end
  end

  describe 'Norairrecord.table factory method' do
    it 'creates an anonymous table class with given configuration' do
      table_class = Norairrecord.table('key123', 'base456', 'My Table')
      expect(table_class.api_key).to eq('key123')
      expect(table_class.base_key).to eq('base456')
      expect(table_class.table_name).to eq('My Table')
    end
  end
end
