class AddApplicationEditStateToAttendances < ActiveRecord::Migration[5.1]
  def change
    add_column :attendances, :application_edit_state, :integer
  end
end
