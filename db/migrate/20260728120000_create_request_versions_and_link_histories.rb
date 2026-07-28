class CreateRequestVersionsAndLinkHistories < ActiveRecord::Migration[8.1]
  def up
    create_table :request_versions do |t|
      t.references :achievement_request, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :title
      t.text :description
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end

    add_index :request_versions, [ :achievement_request_id, :version_number ],
              unique: true, name: "index_request_versions_on_request_and_number"

    add_reference :req_histories, :request_version, null: true, foreign_key: true

    # Backfill: one version per existing request, move proofs, link histories.
    say_with_time "backfill request_versions and reassign proofs" do
      execute <<~SQL.squish
        INSERT INTO request_versions (
          achievement_request_id, version_number, title, description, category_id,
          created_at, updated_at
        )
        SELECT
          id, 1, title, description, category_id,
          created_at, updated_at
        FROM achievement_requests
      SQL

      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET record_type = 'RequestVersion',
            record_id = request_versions.id
        FROM request_versions
        WHERE active_storage_attachments.record_type = 'AchievementRequest'
          AND active_storage_attachments.name = 'proofs'
          AND active_storage_attachments.record_id = request_versions.achievement_request_id
          AND request_versions.version_number = 1
      SQL

      execute <<~SQL.squish
        UPDATE req_histories
        SET request_version_id = request_versions.id
        FROM request_versions
        WHERE req_histories.achievement_request_id = request_versions.achievement_request_id
          AND request_versions.version_number = 1
      SQL
    end

    change_column_null :req_histories, :request_version_id, false
  end

  def down
    remove_reference :req_histories, :request_version, foreign_key: true

    execute <<~SQL.squish
      UPDATE active_storage_attachments
      SET record_type = 'AchievementRequest',
          record_id = request_versions.achievement_request_id
      FROM request_versions
      WHERE active_storage_attachments.record_type = 'RequestVersion'
        AND active_storage_attachments.name = 'proofs'
        AND active_storage_attachments.record_id = request_versions.id
    SQL

    drop_table :request_versions
  end
end
