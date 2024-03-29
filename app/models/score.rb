class Score < ActiveRecord::Base
  belongs_to :question  
  
  # Computes the total score for a list of assessments
  # parameters
  #  assessments - a list of assessments of some type (e.g., author feedback, teammate review)
  #  questions - the list of questions that was filled out in the process of doing those assessments
  def self.compute_scores(assessments, questions)
    scores = Hash.new
    if assessments.length > 0
      scores[:max] = -999999999
      scores[:min] = 999999999
      total_score = 0
      assessments.each {
        | assessment |
        curr_score = get_total_score(assessment, questions)
        if curr_score > scores[:max]
          scores[:max] = curr_score
        end
        if curr_score < scores[:min]
          scores[:min] = curr_score
        end
        total_score += curr_score
      }
      scores[:avg] = total_score.to_f / assessments.length.to_f
    else 
      scores[:max] = nil
      scores[:min] = nil
      scores[:avg] = nil
    end
    return scores 
  end  
  
  # Computes the total score for an assessment
  # params
  #  assessment - specifies the assessment for which the total score is being calculated
  #  questions  - specifies the list of questions being evaluated in the assessment
  def self.get_total_score(response, questions)
    weighted_score = 0
    sum_of_weights = 0
    questions.each{
      | question |
      item = Score.find_by_response_id_and_question_id(response.id, question.id)
      if item != nil and question.section == 0
        weighted_score += item.score * question.weight
        sum_of_weights += question.weight
      end
    }
    orig_score = (weighted_score.to_f / (sum_of_weights.to_f * questions.first.questionnaire.max_question_score.to_f)) * 100

    weighted_score = 0
    sum_of_weights = 0
    @last_question = nil
    questions.each{
      | question |
      item = Score.find_by_response_id_and_question_id(response.id, question.id)
      if item != nil and question.section != 0
        weighted_score += item.score * question.weight
        sum_of_weights += question.weight
      end
      @last_question = question
    }

    ec_score = 0
    if !@last_question.nil?
      @ec_limit = Section.find_by_questionnaire_id(@last_question.questionnaire_id)
      if !@ec_limit.nil?
        ec_score = (weighted_score.to_f / (sum_of_weights.to_f * questions.first.questionnaire.max_question_score.to_f)) * @ec_limit.extra_credit_weightage
      end
    end

    return (orig_score+ec_score)

  end
end
