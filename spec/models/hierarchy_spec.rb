require "rails_helper"

RSpec.describe Hierarchy do
  before do
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
  end

  describe "#make_default!" do
    it "demotes the previous default in the same scope only" do
      old_div = Hierarchy.default_for("division")
      old_sub = Hierarchy.default_for("sub_division")

      custom = Hierarchy.create!(
        name: "Custom Division #{SecureRandom.hex(3)}",
        scope: "division",
        is_default: false
      )
      custom.hierarchy_roles.create!(
        review_role: ReviewRole.dean,
        position: 1,
        can_raise_on_behalf: false
      )

      custom.make_default!

      expect(custom.reload).to be_is_default
      expect(old_div.reload).not_to be_is_default
      expect(old_sub.reload).to be_is_default
      expect(Hierarchy.where(scope: "division", is_default: true).count).to eq(1)
      expect(Hierarchy.where(scope: "sub_division", is_default: true).count).to eq(1)
    end

    it "does not move existing owners when the default changes" do
      old_default = Hierarchy.default_for("division")
      division = create(:division)
      expect(division.hierarchy_id).to eq(old_default.id)

      custom = Hierarchy.create!(
        name: "Promo Division #{SecureRandom.hex(3)}",
        scope: "division",
        is_default: false
      )
      custom.hierarchy_roles.create!(
        review_role: ReviewRole.dean,
        position: 1,
        can_raise_on_behalf: false
      )

      custom.make_default!

      expect(division.reload.hierarchy_id).to eq(old_default.id)
      expect(Hierarchy.default_for("division")).to eq(custom)
    end
  end

  describe "#destroy" do
    it "blocks deleting the default hierarchy" do
      default = Hierarchy.default_for("division")

      expect(default.destroy).to be(false)
      expect(default.errors[:base]).to include("Default hierarchies cannot be deleted")
      expect(Hierarchy.exists?(default.id)).to be(true)
    end

    it "blocks deleting a hierarchy that still has owners" do
      custom = Hierarchy.create!(
        name: "Owned Division #{SecureRandom.hex(3)}",
        scope: "division",
        is_default: false
      )
      custom.hierarchy_roles.create!(
        review_role: ReviewRole.dean,
        position: 1,
        can_raise_on_behalf: false
      )
      division = create(:division)
      division.update!(hierarchy: custom)

      expect(custom.destroy).to be(false)
      expect(custom.errors[:base]).to include("Cannot delete a hierarchy that is still in use")
      expect(Hierarchy.exists?(custom.id)).to be(true)
    end

    it "allows deleting an empty non-default hierarchy" do
      custom = Hierarchy.create!(
        name: "Disposable Division #{SecureRandom.hex(3)}",
        scope: "division",
        is_default: false
      )
      custom.hierarchy_roles.create!(
        review_role: ReviewRole.dean,
        position: 1,
        can_raise_on_behalf: false
      )

      expect { custom.destroy! }.to change(Hierarchy, :count).by(-1)
    end
  end
end
