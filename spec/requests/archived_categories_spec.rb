require "rails_helper"

RSpec.describe "Archived categories and new requests", type: :request do
  let(:division) { create(:division, name: "Visible Division") }
  let(:sub_division) { create(:sub_division, division: division) }
  let!(:active_category) { create(:category, sub_division: sub_division, name: "Active Category") }
  let!(:archived_category) { create(:category, sub_division: sub_division, name: "Archived Category", archived_at: 1.day.ago) }

  describe "student submission (Path A)" do
    let(:student) { create(:student) }

    before { sign_in student.user }

    it "excludes archived categories from the cascading selects" do
      get "/student/achievement_requests/new"

      expect(response.body).to include("Active Category")
      expect(response.body).not_to include("Archived Category")
    end

    it "rejects a crafted submission against an archived category" do
      post "/student/achievement_requests", params: {
        achievement_request: {
          category_id: archived_category.id, title: "Sneaky", description: "x",
          proofs: [ fixture_file_upload("proof.png", "image/png") ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("has been archived and no longer accepts new requests")
    end
  end

  describe "supervisor initiation (Path B)" do
    let(:supervisor) { sub_division.supervisor }
    let(:student) { create(:student) }

    before { sign_in supervisor }

    it "excludes archived categories from the category picker" do
      get "/supervisor/achievement_requests/new"

      expect(response.body).to include("Active Category")
      expect(response.body).not_to include("Archived Category")
    end

    it "rejects raising a request against an archived category" do
      post "/supervisor/achievement_requests", params: {
        achievement_request: {
          student_id: student.id, category_id: archived_category.id, title: "Sneaky",
          description: "x", proofs: [ fixture_file_upload("proof.png", "image/png") ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be under one of your sub-divisions")
    end
  end
end
