class AddSectionColToQuestions < ActiveRecord::Migration

  def self.up
    add_column :questions, :section, :integer, :default => 0
  end

  def self.down
    remove_column :questions, :section
  end

end
