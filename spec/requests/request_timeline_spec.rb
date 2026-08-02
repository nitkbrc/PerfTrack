require "rails_helper"

RSpec.describe "Request timeline UI", type: :request do
  let(:student)      { create(:student) }
  let(:supervisor)   { create(:user, :faculty, name: "Prof. Supervisor") }
  let(:dean)         { create(:user, :faculty, name: "Dean Person") }
  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }

  let!(:request_record) do
    create(:achievement_request, student: student, category: category, title: "Original title",
           at_step: :supervisor).tap do |r|
      v1 = r.current_version
      r.req_histories.create!(actor: student.user, action: "submit", to_status: "in_review",
                              request_version: v1)
      r.revert!(actor: supervisor, comment: "Need clearer proof on version 1")
      r.resubmit!(actor: student.user,
                  attrs: { title: "Revised title", description: "Second attempt" })
      r.revert!(actor: supervisor, comment: "Still missing date on version 2")
    end
  end

  def timeline_markers(body)
    {
      versions: body.scan(/Version \d/).uniq,
      v1_comment: body.include?("Need clearer proof on version 1"),
      v2_comment: body.include?("Still missing date on version 2"),
      original_title: body.include?("Original title"),
      revised_title: body.include?("Revised title"),
      timeline_heading: body.include?("Timeline"),
      carousel: body.include?('data-controller="version-carousel"'),
      prev_arrow: body.include?('data-version-carousel-target="prev"'),
      next_arrow: body.include?('data-version-carousel-target="next"'),
      slides: body.scan(/data-version-carousel-target="slide"/).size
    }
  end

  it "shows the same two-version carousel with comments under the correct version for all roles" do
    expect(request_record.request_versions.count).to eq(2)

    sign_in student.user
    get student_achievement_request_path(request_record)
    student_markers = timeline_markers(response.body)

    sign_in supervisor
    get supervisor_achievement_request_path(request_record)
    supervisor_markers = timeline_markers(response.body)

    sign_in dean
    get dean_achievement_request_path(request_record)
    dean_markers = timeline_markers(response.body)

    expect(student_markers).to eq(
      versions: [ "Version 1", "Version 2" ],
      v1_comment: true,
      v2_comment: true,
      original_title: true,
      revised_title: true,
      timeline_heading: true,
      carousel: true,
      prev_arrow: true,
      next_arrow: true,
      slides: 2
    )
    expect(supervisor_markers).to eq(student_markers)
    expect(dean_markers).to eq(student_markers)

    # Both slides remain in the DOM (one hidden). Version-1 comment precedes Version 2.
    v1_comment_at = response.body.index("Need clearer proof on version 1")
    v2_heading_at = response.body.index("Version 2")
    v2_comment_at = response.body.index("Still missing date on version 2")
    expect(v1_comment_at).to be < v2_heading_at
    expect(v2_heading_at).to be < v2_comment_at

    # Defaults to latest: next arrow starts hidden; prev is available for older versions.
    doc = Nokogiri::HTML(response.body)
    prev_btn = doc.at_css('[data-version-carousel-target="prev"]')
    next_btn = doc.at_css('[data-version-carousel-target="next"]')
    expect(prev_btn).to be_present
    expect(next_btn).to be_present
    expect(prev_btn["hidden"]).to be_nil
    expect(next_btn["hidden"]).not_to be_nil
  end

  it "hides both carousel arrows when there is only one version" do
    single = create(:achievement_request, student: student, category: category, title: "Only version")

    sign_in student.user
    get student_achievement_request_path(single)

    expect(response.body).to include('data-controller="version-carousel"')
    expect(response.body).to include("Version 1")
    expect(response.body).to include("Only version")
    expect(response.body.scan(/data-version-carousel-target="slide"/).size).to eq(1)

    doc = Nokogiri::HTML(response.body)
    prev_btn = doc.at_css('[data-version-carousel-target="prev"]')
    next_btn = doc.at_css('[data-version-carousel-target="next"]')
    expect(prev_btn["hidden"]).not_to be_nil
    expect(next_btn["hidden"]).not_to be_nil
  end

  it "shows Path B revise as a second version after dean revert" do
    proof = Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
    path_b = AchievementRequest.supervisor_initiate!(
      student: student,
      actor: supervisor,
      attrs: { category_id: category.id, title: "Original Path B", description: "First cut",
               proofs: [ proof ] }
    )
    path_b.revert!(actor: dean, comment: "Clarify the dates")
    path_b.revise!(actor: supervisor,
                   attrs: { title: "Clarified Path B", description: "Dates fixed" })

    expect(path_b.request_versions.count).to eq(2)

    sign_in supervisor
    get supervisor_achievement_request_path(path_b)

    expect(response.body).to include("Version 1")
    expect(response.body).to include("Version 2")
    expect(response.body).to include("Original Path B")
    expect(response.body).to include("Clarified Path B")
    expect(response.body).to include("Clarify the dates")
    expect(response.body).to include("Revised by supervisor after feedback")
    expect(response.body).to include('data-controller="version-carousel"')
    expect(response.body.scan(/data-version-carousel-target="slide"/).size).to eq(2)
  end
end
