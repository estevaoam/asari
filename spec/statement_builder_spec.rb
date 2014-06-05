require_relative '../spec_helper'

describe Asari::StatementBuilder do
  subject { described_class.new(key, value) }

  context "doing conversions" do
    let(:key) { "test" }

    context "ranges" do
      let(:value) { 10..20 }

      it "is in the valid format" do
        expect(subject.build).to eq("test:[10,20]")
      end
    end

    context "integer" do
      let(:value) { 999 }

      it "is in the valid format" do
        expect(subject.build).to eq("test:999")
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
