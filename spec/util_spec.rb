require 'spec_helper'

RSpec.describe Norairrecord::Util do
  describe '.all_of' do
    it 'wraps conditions in AND formula' do
      result = described_class.all_of('condition1', 'condition2', 'condition3')
      expect(result).to eq('AND(condition1,condition2,condition3)')
    end

    it 'works with single condition' do
      result = described_class.all_of('condition1')
      expect(result).to eq('AND(condition1)')
    end

    it 'works with no conditions' do
      result = described_class.all_of
      expect(result).to eq('AND()')
    end

    it 'works with complex nested conditions' do
      result = described_class.all_of('Name="Test"', 'Status="Active"', '{Count}>5')
      expect(result).to eq('AND(Name="Test",Status="Active",{Count}>5)')
    end
  end

  describe '.any_of' do
    it 'wraps conditions in OR formula' do
      result = described_class.any_of('condition1', 'condition2', 'condition3')
      expect(result).to eq('OR(condition1,condition2,condition3)')
    end

    it 'works with single condition' do
      result = described_class.any_of('condition1')
      expect(result).to eq('OR(condition1)')
    end

    it 'works with no conditions' do
      result = described_class.any_of
      expect(result).to eq('OR()')
    end

    it 'works with complex nested conditions' do
      result = described_class.any_of('Type="A"', 'Type="B"', 'Type="C"')
      expect(result).to eq('OR(Type="A",Type="B",Type="C")')
    end
  end

  describe '.none_of' do
    it 'wraps conditions in NOT(AND()) formula' do
      result = described_class.none_of('condition1', 'condition2')
      expect(result).to eq('NOT(AND(condition1,condition2))')
    end

    it 'works with single condition' do
      result = described_class.none_of('condition1')
      expect(result).to eq('NOT(AND(condition1))')
    end

    it 'works with no conditions' do
      result = described_class.none_of
      expect(result).to eq('NOT(AND())')
    end

    it 'negates multiple conditions' do
      result = described_class.none_of('Status="Deleted"', 'Status="Archived"')
      expect(result).to eq('NOT(AND(Status="Deleted",Status="Archived"))')
    end
  end

  describe '.field_is_any' do
    it 'creates OR formula for field matching any value' do
      result = described_class.field_is_any('Status', 'Active', 'Pending', 'Review')
      expect(result).to eq("OR(Status='Active',Status='Pending',Status='Review')")
    end

    it 'works with single value' do
      result = described_class.field_is_any('Type', 'TypeA')
      expect(result).to eq("OR(Type='TypeA')")
    end

    it 'sanitizes values with quotes' do
      result = described_class.field_is_any('Name', "O'Brien", 'Smith')
      expect(result).to eq("OR(Name='O\\'Brien',Name='Smith')")
    end

    it 'sanitizes values with double quotes' do
      result = described_class.field_is_any('Description', 'Said "hello"', 'Other')
      expect(result).to eq('OR(Description=\'Said \\"hello\"\',Description=\'Other\')')
    end

    it 'works with no values' do
      result = described_class.field_is_any('Field')
      expect(result).to eq("OR()")
    end
  end

  describe '.sanitize' do
    it 'escapes single quotes' do
      result = described_class.sanitize("O'Brien")
      expect(result).to eq("O\\'Brien")
    end

    it 'escapes double quotes' do
      result = described_class.sanitize('Said "hello"')
      expect(result).to eq('Said \\"hello\\"')
    end

    it 'escapes both single and double quotes' do
      result = described_class.sanitize(%q{It's a "test"})
      expect(result).to eq(%q{It\\'s a \\"test\\"})
    end

    it 'handles multiple quotes' do
      result = described_class.sanitize("'quoted' and \"more quotes\"")
      expect(result).to eq("\\'quoted\\' and \\\"more quotes\\\"")
    end

    it 'returns unchanged string without quotes' do
      result = described_class.sanitize("NoQuotesHere")
      expect(result).to eq("NoQuotesHere")
    end

    it 'handles empty string' do
      result = described_class.sanitize("")
      expect(result).to eq("")
    end
  end

  describe '.mass_sanitize' do
    it 'sanitizes multiple arguments' do
      result = described_class.mass_sanitize("O'Brien", 'Said "hello"', 'Normal')
      expect(result).to eq(["O\\'Brien", 'Said \\"hello\\"', 'Normal'])
    end

    it 'works with single argument' do
      result = described_class.mass_sanitize("It's")
      expect(result).to eq(["It\\'s"])
    end

    it 'works with no arguments' do
      result = described_class.mass_sanitize
      expect(result).to eq([])
    end

    it 'preserves array structure' do
      result = described_class.mass_sanitize('a', 'b', 'c')
      expect(result).to be_a(Array)
      expect(result.length).to eq(3)
    end
  end

  describe 'module functions' do
    it 'can be called as module functions' do
      expect(Norairrecord::Util.all_of('a', 'b')).to eq('AND(a,b)')
      expect(Norairrecord::Util.any_of('a', 'b')).to eq('OR(a,b)')
      expect(Norairrecord::Util.none_of('a', 'b')).to eq('NOT(AND(a,b))')
      expect(Norairrecord::Util.field_is_any('Field', 'a', 'b')).to eq("OR(Field='a',Field='b')")
      expect(Norairrecord::Util.sanitize("it's")).to eq("it\\'s")
      expect(Norairrecord::Util.mass_sanitize('a', 'b')).to eq(['a', 'b'])
    end
  end

  describe 'inclusion in classes' do
    let(:test_class) do
      Class.new do
        class << self
          include Norairrecord::Util
          
          # Make methods public for testing
          public :all_of, :any_of, :none_of, :sanitize
        end
      end
    end

    it 'can be included in singleton class' do
      expect(test_class.all_of('a', 'b')).to eq('AND(a,b)')
      expect(test_class.any_of('a', 'b')).to eq('OR(a,b)')
      expect(test_class.none_of('a')).to eq('NOT(AND(a))')
      expect(test_class.sanitize("it's")).to eq("it\\'s")
    end
  end

  describe 'complex formula building' do
    it 'can build nested formulas' do
      condition1 = described_class.field_is_any('Status', 'Active', 'Pending')
      condition2 = described_class.all_of('{Count}>5', 'Type="A"')
      result = described_class.any_of(condition1, condition2)
      
      expect(result).to eq("OR(OR(Status='Active',Status='Pending'),AND({Count}>5,Type=\"A\"))")
    end

    it 'can combine with none_of' do
      excluded = described_class.none_of('Status="Deleted"', 'Status="Archived"')
      required = described_class.field_is_any('Priority', 'High', 'Critical')
      result = described_class.all_of(excluded, required)
      
      expect(result).to eq("AND(NOT(AND(Status=\"Deleted\",Status=\"Archived\")),OR(Priority='High',Priority='Critical'))")
    end
  end
end
