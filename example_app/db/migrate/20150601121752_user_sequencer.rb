class UserSequencer < ActiveRecord::Migration
  use_shard :user
  to_sequencer :user

  def up
    table_name = self.class.sequencer_table_name
    create_table table_name, id: false, options: "ENGINE=MyISAM DEFAULT CHARACTER SET=UTF8" do |t|
      t.integer :id, :limit => 8
    end
    execute "INSERT INTO #{table_name} (`id`) VALUES (0)"
  end

  def down
    table_name = self.class.sequencer_table_name
    drop_table table_name
  end
end
