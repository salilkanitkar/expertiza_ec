class AddExtraCreditWeightage < ActiveRecord::Migration
  def self.up
    add_column :sections, :extra_credit_weightage, :integer, :default => 0
  end

  def self.down
    remove_column :sections, :extra_credit_weightage
  end
end
