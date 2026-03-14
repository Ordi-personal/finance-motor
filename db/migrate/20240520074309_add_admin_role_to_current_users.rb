class AddAdminRoleToCurrentUsers < ActiveRecord::Migration[7.2]
  def up
    migration_user.update_all(role: "admin")
  end

  private

    def migration_user
      Class.new(ActiveRecord::Base) do
        self.table_name = "users"
        self.inheritance_column = :_type_disabled
      end
    end
end
