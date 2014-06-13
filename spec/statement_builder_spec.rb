require_relative '../spec_helper'

describe Asari::StatementBuilder do
  subject { described_class.new(key, value) }

  context "doing conversions" do
    let(:key) { "test" }

    context "ranges" do
      context "with integers" do
        let(:value) { 10..20 }

        it "is in the valid format" do
          expect(subject.build).to eq("test:[10,20]")
        end
      end

      context "with dates" do
        let(:time_begin) { Time.strptime('20/01/2013', "%d/%m/%Y") }
        let(:time_end) { Time.strptime('30/01/2013', "%d/%m/%Y") }
        let(:value) { (time_begin)..(time_end) }

        it "is in the valid format" do
          expect(subject.build).to eq("test:['2013-01-20T00:00:00Z','2013-01-30T00:00:00Z']")
        end
      end
    end

    context "integer" do
      let(:value) { 999 }

      it "is in the valid format" do
        expect(subject.build).to eq("test:999")
      end
    end

    context "array" do
      context "with string values" do
        let(:value) { ['test', 'test2'] }

        it "is in the valid format" do
          expect(subject.build).to eq(" test:'test' test:'test2'")
        end
      end

      context "with float values" do
        let(:value) { [9.3, 1.2345] }

        it "is in the valid format" do
          expect(subject.build).to eq(" test:9.3 test:1.2345")
        end
      end

      context "with integer values" do
        let(:value) { [9, 1] }

        it "is in the valid format" do
          expect(subject.build).to eq(" test:9 test:1")
        end
      end

      context "with dates" do
        let(:time_begin) { Time.strptime('20/01/2013', "%d/%m/%Y") }
        let(:time_end) { Time.strptime('30/01/2013', "%d/%m/%Y") }
        let(:value) { [time_begin, time_end] }

        it "is in the valid format" do
          expect(subject.build).to eq(" test:'2013-01-20T00:00:00Z' test:'2013-01-30T00:00:00Z'")
        end
      end
    end

    context "other type" do
      let(:value) { 'oi' }

      it "is in the valid format" do
        expect(subject.build).to eq("test:'oi'")
      end
    end
  end

end
