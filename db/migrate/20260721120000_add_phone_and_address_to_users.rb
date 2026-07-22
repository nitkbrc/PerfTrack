class AddPhoneAndAddressToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :phone, :string, null: false
    add_column :users, :address, :text, null: false
  end
end
