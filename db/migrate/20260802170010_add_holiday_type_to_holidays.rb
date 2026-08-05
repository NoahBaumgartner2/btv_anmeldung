class AddHolidayTypeToHolidays < ActiveRecord::Migration[8.1]
  # Ferien-Instanzen (bisher: einmalige Datumsbereiche mit freiem Titel wie
  # "Herbstferien 2026") gehören ab jetzt zu einem wiederverwendbaren
  # HolidayType (z.B. "Herbstferien"), unter dem jedes Jahr ein neuer
  # Datumsbereich erfasst wird. Bestehende Titel werden 1:1 in HolidayTypes
  # überführt.
  def up
    add_reference :holidays, :holiday_type, foreign_key: true

    execute <<~SQL
      INSERT INTO holiday_types (name, created_at, updated_at)
      SELECT DISTINCT COALESCE(NULLIF(title, ''), 'Ferien'), NOW(), NOW()
      FROM holidays
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE holidays
      SET holiday_type_id = holiday_types.id
      FROM holiday_types
      WHERE holiday_types.name = COALESCE(NULLIF(holidays.title, ''), 'Ferien')
    SQL

    change_column_null :holidays, :holiday_type_id, false
    remove_column :holidays, :title, :string
  end

  def down
    add_column :holidays, :title, :string
    execute <<~SQL
      UPDATE holidays
      SET title = holiday_types.name
      FROM holiday_types
      WHERE holiday_types.id = holidays.holiday_type_id
    SQL
    remove_reference :holidays, :holiday_type, foreign_key: true
  end
end
