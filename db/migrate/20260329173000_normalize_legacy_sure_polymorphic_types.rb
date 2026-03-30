class NormalizeLegacySurePolymorphicTypes < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE accounts
      SET accountable_type = regexp_replace(accountable_type, '^Sure::', '')
      WHERE accountable_type LIKE 'Sure::%'
    SQL

    execute <<~SQL
      UPDATE entries
      SET entryable_type = regexp_replace(entryable_type, '^Sure::', '')
      WHERE entryable_type LIKE 'Sure::%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Legacy polymorphic types cannot be restored safely"
  end
end
