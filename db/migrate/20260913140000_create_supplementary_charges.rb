class CreateSupplementaryCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :supplementary_charges do |t|
      t.references :participant, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.text :description, null: false
      t.text :explanation
      t.string :status, null: false, default: "offen"
      t.string :sumup_checkout_id
      t.string :sumup_transaction_id
      t.datetime :paid_at

      t.timestamps
    end

    add_index :supplementary_charges, :status
    add_index :supplementary_charges, :sumup_checkout_id
  end
end
