class AddSectionsTable < ActiveRecord::Migration
  def self.up
    create_table "sections", :force => true do |t|
      t.column "questionnaire_id", :integer
      t.column "is_extra_credit", :boolean, :default => false
    end

    add_index "sections", ["questionnaire_id"], :name => "fk_questionnaire"

    execute "alter table sections
             add constraint fk_questionnaire
             foreign key (questionnaire_id) references questionnaires(id)"
  end

  def self.down
    drop_table sections
  end
end
