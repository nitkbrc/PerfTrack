require "rails_helper"

RSpec.describe "Admin archiving", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:division) { create(:division, name: "Old Division") }
  let(:sub_division) { create(:sub_division, division: division, name: "Old Sub") }
  let!(:category) { create(:category, sub_division: sub_division, name: "Old Category") }

  before { sign_in admin }

  it "archives a division with its whole subtree" do
    patch "/admin/divisions/#{division.id}/archive"

    expect(response).to redirect_to("/admin/divisions")
    expect(division.reload).to be_archived
    expect(sub_division.reload).to be_archived
    expect(category.reload).to be_archived
  end

  it "hides archived divisions from the default index but shows them in the archived view" do
    division.archive!

    get "/admin/divisions"
    expect(response.body).not_to include("Old Division")
    expect(response.body).to include("Archived (1)")

    get "/admin/divisions", params: { archived: 1 }
    expect(response.body).to include("Old Division")
    expect(response.body).to include("Restore")
  end

  it "restores a division with the subtree it archived" do
    division.archive!

    patch "/admin/divisions/#{division.id}/restore"

    expect(response).to redirect_to("/admin/divisions?archived=1")
    expect(division.reload).not_to be_archived
    expect(sub_division.reload).not_to be_archived
    expect(category.reload).not_to be_archived
  end

  it "refuses to restore a sub-division while its division is archived" do
    division.archive!

    patch "/admin/sub_divisions/#{sub_division.id}/restore"

    expect(flash[:alert]).to eq("Restore the Old Division division first.")
    expect(sub_division.reload).to be_archived
  end

  it "refuses to restore a category while its sub-division is archived" do
    sub_division.archive!

    patch "/admin/categories/#{category.id}/restore"

    expect(flash[:alert]).to eq("Restore the Old Sub sub-division first.")
    expect(category.reload).to be_archived
  end

  it "restores a category once its parents are active" do
    category.archive!

    patch "/admin/categories/#{category.id}/restore"

    expect(category.reload).not_to be_archived
  end
end
