class AddAasmStateToGame < ActiveRecord::Migration
  def change
    add_column :games, :aasm_state, :string
  end
end
