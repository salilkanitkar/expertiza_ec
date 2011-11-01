require 'fastercsv'

module GradesHelper

  def self.format_score (score)
    return sprintf("%.2f%",score) if score.blank? == false;
    return "-"
  end

  def self.create_grade_csv(scores)
    #if scores.blank?
     # return
    #end
    puts("AREY AREY AREY!!!")
    if !scores.nil?
      if scores.has_key?("teams")
        return create_team_grade_csv(scores)
      end
      if scores.has_key?("participants")
         return create_participant_grade_csv(scores)
      end
    end

  end


  def self.create_team_grade_csv (scores)
    team_csv_data = FasterCSV.generate do |csv|
      row = Array.new

      if scores.has_key?("teams")
        row << "Contributor"
        row << " "
        row << "Submitted work"
        row << " "
        row << "Reviewing"
        row << " "
        row << "Author Feedback"
        row << " "
        row << "Teammate Review"
        row << " "
        row << "Final Score"
        csv << row
        row.clear
        row << "Name "
        row << "Handle"
        1.upto 4 do
          row << "Average"
          row << "Range"
        end
        csv << row

        scores[:teams].each_value {|team|
          row.clear
          row << Team.find(team[:team]).name
          row << " "
          row << format_score(team[:scores][:avg])
          row << "#{format_score(team[:scores][:min])} - #{format_score(team[:scores][:max])}"
          csv << row
          row.clear

          scores[:participants].each_pair {|participant,score|
            participant_detail = User.find(Participant.find(participant).user_id)
            teams_users=TeamsUser.find_by_team_id_and_user_id(team[:team],participant_detail.id)
            if !teams_users.blank?
              row << teams_users.user.fullname
              row << teams_users.user.handle

              if score.has_key?("review")
                row << format_score(score[:review][:scores][:avg])
                row << "#{format_score(score[:review][:scores][:min])} - #{format_score(score[:review][:scores][:max])}"
              else
                row << "--"
                row << "--"
              end

              if score.has_key?("metareview")
                row << format_score(score[:metareview][:scores][:avg])
                row << "#{format_score(score[:metareview][:scores][:min])} -
 #{format_score(score[:metareview][:scores][:max])}"
              else
                              row << "--"
                              row << "--"
              end

              if score.has_key?("feedback")
                row << format_score(score[:feedback][:scores][:avg])
                row << "#{format_score(score[:feedback][:scores][:min])} -
 #{format_score(score[:feedback][:scores][:max])}"
              else
                              row << "--"
                              row << "--"

              end

              if score.has_key?("teammate")
                row << format_score(score[:teammate][:scores][:avg])
                row << "#{format_score(score[:teammate][:scores][:min])} -
 #{format_score(score[:teammate][:scores][:max])}"
              else
                              row << "--"
                              row << "--"

              end

              score.has_key?("total_score") ?  row << format_score(score[:total_score]) : row << " -- "
              csv << row
              row.clear
            end

          }
          row.clear
          csv << row
        }
      end
    end
    return team_csv_data
  end



  def self.create_participant_grade_csv (scores)

    participant_csv_data = FasterCSV.generate do |csv|
      row = Array.new
      row << "Contributor"
      row << " "
      row << "Submitted work"
      row << " "
      row << "Reviewing"
      row << " "
      row << "Author Feedback"
      row << " "
      row << "Final Score"
      csv << row

      row.clear
      row << "Name "
      row << "Handle"

      1.upto 3 do
        row << "Average"
        row << "Range"
      end

      csv << row
      row.clear

      for participant in scores[:participants]
        row.clear
        participant=participant[1]
        participant_detail = User.find(Participant.find(participant[:participant]).user_id)
        row << participant_detail.fullname
        row << participant_detail.handle

        if participant.has_key?("review")
          row << format_score(participant[:review][:scores][:avg])
          row << "#{format_score(participant[:review][:scores][:min])} - #{format_score(participant[:review][:scores][:max])}"
        else
                        row << "--"
                        row << "--"

        end

        if participant.has_key?("metareview")
          row << format_score(participant[:metareview][:scores][:avg])
          row << "#{format_score(participant[:metareview][:scores][:min])} - #{format_score(participant[:metareview][:scores][:max])}"
        else
                        row << "--"
                        row << "--"

        end

        if participant.has_key?("feedback")
          row << format_score(participant[:feedback][:scores][:avg])
          row << "#{format_score(participant[:feedback][:scores][:min])} - #{format_score(participant[:feedback][:scores][:max])}"
        else
                        row << "--"
                        row << "--"

        end

        participant.has_key?("total_score") ?  row << format_score(participant[:total_score]): row << "--"

        csv << row
      end
    end
    return participant_csv_data
  end

end


