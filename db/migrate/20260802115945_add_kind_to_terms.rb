class AddKindToTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :terms, :kind, :string
  end
end
