class CreateSections < ActiveRecord::Migration
  def self.up
    create_table :sections do |t|
      t.boolean :is_extra_credit

      t.timestamps
      t.references :questionnaire
    end
  end

  def self.down
    drop_table :sections
  end
end
