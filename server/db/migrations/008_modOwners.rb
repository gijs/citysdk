Sequel.migration do

    
  up do
    $stderr.puts("Adapting owners...")


    add_column :owners, :salt, String
    add_column :owners, :passwd, String

    add_column :owners, :session, String
    add_column :owners, :timeout, DateTime
  end
    
    
  down do
    remove_column :owners, :salt
    remove_column :owners, :passwd

    remove_column :owners, :session
    remove_column :owners, :timeout
  end

end
