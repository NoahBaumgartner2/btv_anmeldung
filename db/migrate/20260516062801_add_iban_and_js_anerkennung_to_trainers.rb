class AddIbanAndJsAnerkennungToTrainers < ActiveRecord::Migration[8.1]
  def change
    add_column :trainers, :iban, :string
    add_column :trainers, :js_anerkennung, :boolean, default: false, null: false
  end
end
