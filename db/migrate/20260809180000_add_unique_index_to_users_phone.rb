# frozen_string_literal: true

class AddUniqueIndexToUsersPhone < ActiveRecord::Migration[8.1]
  def up
    say_with_time "normalize user phones to digits only" do
      User.reset_column_information
      User.find_each do |user|
        digits = user.phone.to_s.gsub(/\D/, "")
        user.update_columns(phone: digits) if digits != user.phone
      end
    end

    say_with_time "dedupe colliding phones (keep earliest id)" do
      duplicates = User.group(:phone).having("COUNT(*) > 1").pluck(:phone)
      duplicates.each do |phone|
        holders = User.where(phone: phone).order(:id).to_a
        holders.drop(1).each_with_index do |user, index|
          candidate = "#{phone}#{index + 1}"
          while User.exists?(phone: candidate)
            candidate = "#{candidate}9"
          end
          user.update_columns(phone: candidate)
        end
      end
    end

    add_index :users, :phone, unique: true
  end

  def down
    remove_index :users, :phone
  end
end
