require "rails_helper"

RSpec.describe Setting, type: :model do
  it "defaults score_scale_k to 50" do
    expect(described_class.instance.score_scale_k).to eq(50)
  end

  it "rejects non-positive k values" do
    expect(build(:setting, score_scale_k: 0)).not_to be_valid
    expect(build(:setting, score_scale_k: -5)).not_to be_valid
  end

  it "returns the same row from .instance" do
    expect(described_class.instance.id).to eq(described_class.instance.id)
    expect(described_class.count).to eq(1)
  end
end
