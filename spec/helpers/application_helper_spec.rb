require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#ethos_tier" do
    it "returns Black for 0.0" do
      expect(helper.ethos_tier(0.0)[:name]).to eq("Black")
    end

    it "returns Black for 1.4" do
      expect(helper.ethos_tier(1.4)[:name]).to eq("Black")
    end

    it "returns Red for 1.5" do
      expect(helper.ethos_tier(1.5)[:name]).to eq("Red")
    end

    it "returns Red for 3.4" do
      expect(helper.ethos_tier(3.4)[:name]).to eq("Red")
    end

    it "returns Orange for 3.5" do
      expect(helper.ethos_tier(3.5)[:name]).to eq("Orange")
    end

    it "returns Bronze for 5.0" do
      expect(helper.ethos_tier(5.0)[:name]).to eq("Bronze")
    end

    it "returns Silver for 6.5" do
      expect(helper.ethos_tier(6.5)[:name]).to eq("Silver")
    end

    it "returns Gold for 8.5" do
      expect(helper.ethos_tier(8.5)[:name]).to eq("Gold")
    end

    it "returns Gold for 10.0" do
      expect(helper.ethos_tier(10.0)[:name]).to eq("Gold")
    end
  end

  describe "#integrity_index" do
    let(:student) { instance_double(Student) }

    it "returns 100 on a clean slate (no approved points)" do
      allow(student).to receive(:positive_total).and_return(0)
      allow(student).to receive(:negative_total).and_return(0)
      expect(helper.integrity_index(student)).to eq(100)
    end

    it "returns 0 when only negative points exist" do
      allow(student).to receive(:positive_total).and_return(0)
      allow(student).to receive(:negative_total).and_return(-10)
      expect(helper.integrity_index(student)).to eq(0)
    end

    it "returns 100 when only positive points exist" do
      allow(student).to receive(:positive_total).and_return(20)
      allow(student).to receive(:negative_total).and_return(0)
      expect(helper.integrity_index(student)).to eq(100)
    end

    it "computes correct ratio for mixed points" do
      allow(student).to receive(:positive_total).and_return(75)
      allow(student).to receive(:negative_total).and_return(-25)
      expect(helper.integrity_index(student)).to eq(75)
    end
  end

  describe "#integrity_risk" do
    it "returns Minimal Risk for index >= 85" do
      expect(helper.integrity_risk(85)[:label]).to eq("Minimal Risk")
      expect(helper.integrity_risk(100)[:label]).to eq("Minimal Risk")
    end

    it "returns Moderate Risk for 60..84" do
      expect(helper.integrity_risk(60)[:label]).to eq("Moderate Risk")
      expect(helper.integrity_risk(84)[:label]).to eq("Moderate Risk")
    end

    it "returns Elevated Risk for index < 60" do
      expect(helper.integrity_risk(59)[:label]).to eq("Elevated Risk")
      expect(helper.integrity_risk(0)[:label]).to eq("Elevated Risk")
    end
  end
end
