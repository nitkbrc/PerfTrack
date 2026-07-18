require "rails_helper"

RSpec.describe "Archiving the division tree" do
  let(:division) { create(:division) }
  let(:sub_division) { create(:sub_division, division: division) }
  let!(:category) { create(:category, sub_division: sub_division) }

  it "archiving a division cascades to its sub-divisions and categories" do
    division.archive!

    expect(division.reload).to be_archived
    expect(sub_division.reload).to be_archived
    expect(category.reload).to be_archived
  end

  it "restoring a division brings back everything archived by its cascade" do
    division.archive!
    division.restore!

    expect(division.reload).not_to be_archived
    expect(sub_division.reload).not_to be_archived
    expect(category.reload).not_to be_archived
  end

  it "restoring a division leaves individually archived children archived" do
    category.archive!
    division.archive!
    division.restore!

    expect(sub_division.reload).not_to be_archived
    expect(category.reload).to be_archived
  end

  it "archiving a sub-division cascades to its categories but not its division" do
    sub_division.archive!

    expect(division.reload).not_to be_archived
    expect(sub_division.reload).to be_archived
    expect(category.reload).to be_archived
  end

  it "prevents new requests in an archived category but keeps existing ones" do
    request = create(:achievement_request, category: category)
    category.archive!

    fresh = build(:achievement_request, category: category.reload)
    expect(fresh).not_to be_valid
    expect(fresh.errors[:category]).to include("has been archived and no longer accepts new requests")

    expect(request.reload).to be_valid
  end
end
