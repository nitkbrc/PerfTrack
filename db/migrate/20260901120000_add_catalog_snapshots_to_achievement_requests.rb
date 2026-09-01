class AddCatalogSnapshotsToAchievementRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :achievement_requests, bulk: true do |t|
      t.string :snapshot_category_name
      t.integer :snapshot_category_points
      t.string :snapshot_sub_division_name
      t.string :snapshot_division_name
      t.string :snapshot_div_type
    end

    reversible do |dir|
      dir.up { backfill_catalog_snapshots }
    end
  end

  private

  def backfill_catalog_snapshots
    say_with_time "Backfill catalog snapshots for decided requests" do
      AchievementRequest.where(status: %w[approved rejected])
                        .includes(category: { sub_division: :division })
                        .find_each do |request|
        category = request.category
        next if category.blank?

        sub = category.sub_division
        div = sub&.division
        next if sub.blank? || div.blank?

        div_type =
          if request.approved? && request.points_awarded.present?
            request.points_awarded.positive? ? "positive" : "negative"
          else
            div.div_type
          end

        request.update_columns(
          snapshot_category_name: category.name,
          snapshot_category_points: category.points,
          snapshot_sub_division_name: sub.name,
          snapshot_division_name: div.name,
          snapshot_div_type: div_type,
          updated_at: Time.current
        )
      end
    end
  end
end
