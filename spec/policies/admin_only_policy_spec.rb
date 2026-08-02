require "rails_helper"

RSpec.describe AdminOnlyPolicy do
  let(:admin)   { build_stubbed(:user, :admin) }
  let(:faculty) { build_stubbed(:user, :faculty) }
  let(:student) { build_stubbed(:user) }

  # Behavior is shared; DivisionPolicy stands in for all six subclasses.
  describe DivisionPolicy do
    let(:record) { build_stubbed(:division) }

    %i[index? show? create? new? update? edit? destroy?].each do |action|
      it "permits an admin to #{action}" do
        expect(described_class.new(admin, record).public_send(action)).to be true
      end

      it "denies faculty to #{action}" do
        expect(described_class.new(faculty, record).public_send(action)).to be false
      end

      it "denies a student to #{action}" do
        expect(described_class.new(student, record).public_send(action)).to be false
      end
    end
  end

  describe "Scope" do
    it "returns all records for an admin and none for others" do
      division = create(:division)

      expect(DivisionPolicy::Scope.new(admin, Division.all).resolve).to include(division)
      expect(DivisionPolicy::Scope.new(faculty, Division.all).resolve).to be_empty
      expect(DivisionPolicy::Scope.new(student, Division.all).resolve).to be_empty
    end
  end

  it "permits admins for unknown custom actions instead of raising NotDefinedError" do
    policy = DivisionPolicy.new(admin, build_stubbed(:division))
    expect(policy.public_send(:bulk_apply?)).to be true
    expect(policy.public_send(:move_up?)).to be true
  end

  it "denies non-admins for unknown custom actions instead of raising NotDefinedError" do
    policy = DivisionPolicy.new(faculty, build_stubbed(:division))
    expect(policy.public_send(:bulk_apply?)).to be false
  end

  it "backs all six admin-managed resources" do
    [ DivisionPolicy, SubDivisionPolicy, CategoryPolicy,
      DepartmentPolicy, ReasonTemplatePolicy, UserPolicy ].each do |policy|
      expect(policy.ancestors).to include(described_class)
    end
  end
end
