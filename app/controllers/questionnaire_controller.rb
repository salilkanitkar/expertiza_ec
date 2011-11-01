class QuestionnaireController < ApplicationController
  # Controller for Questionnaire objects
  # A Questionnaire can be of several types (QuestionnaireType)
  # Each Questionnaire contains zero or more questions (Question)
  # Generally a questionnaire is associated with an assignment (Assignment)  
  before_filter :authorize
  
  # Create a clone of the given questionnaire, copying all associated
  # questions. The name and creator are updated.
  def copy
    orig_questionnaire = Questionnaire.find(params[:id])
    questions = Question.find_all_by_questionnaire_id(params[:id])               
    @questionnaire = orig_questionnaire.clone
    
    if (session[:user]).role.name != "Teaching Assistant"
      @questionnaire.instructor_id = session[:user].id
    else # for TA we need to get his instructor id and by default add it to his course for which he is the TA
      @questionnaire.instructor_id = Ta.get_my_instructor((session[:user]).id)
    end
    @questionnaire.name = 'Copy of '+orig_questionnaire.name
    
    begin
      @questionnaire.save! 
      @questionnaire.update_attribute('created_at',Time.now)
      questions.each{
        | question |
        newquestion = question.clone
        newquestion.questionnaire_id = @questionnaire.id
        newquestion.save        
        
        advice = QuestionAdvice.find_by_question_id(question.id)
        newadvice = advice.clone
        newadvice.question_id = newquestion.id
        newadvice.save
      }       
      pFolder = TreeFolder.find_by_name(@questionnaire.display_type)
      parent = FolderNode.find_by_node_object_id(pFolder.id)
      if QuestionnaireNode.find_by_parent_id_and_node_object_id(parent.id,@questionnaire.id) == nil
        QuestionnaireNode.create(:parent_id => parent.id, :node_object_id => @questionnaire.id)
      end
      redirect_to :controller => 'questionnaire', :action => 'view', :id => @questionnaire.id
    rescue
      flash[:error] = 'The questionnaire was not able to be copied. Please check the original course for missing information.'+$!      
      redirect_to :action => 'list', :controller => 'tree_display'
    end            
  end
     
  # Remove a given questionnaire
  def delete
    questionnaire = Questionnaire.find(params[:id])
    
    if questionnaire
       begin
          id = questionnaire.id
          temp = Section.find_by_questionnaire_id(id)
          if !temp.blank?
            temp.delete
          end

          name = questionnaire.name
          questionnaire.delete
          flash[:note] = "Questionnaire <B>#{name}</B> was deleted."
      rescue
          flash[:error] = $!
      end
    end
    
    redirect_to :action => 'list', :controller => 'tree_display'   
  end
  
  # View a questionnaire
  def view
    @questionnaire = Questionnaire.find(params[:id])
    @extra_credit = []
  end
  
  # Edit a questionnaire
  def edit
    @weightage = Section.find_by_questionnaire_id(params[:id])
    save_weightage params[:id]

    begin
    @questionnaire = Questionnaire.find(params[:id])
    redirect_to :action => 'list' if @questionnaire == nil

    if params['ecWeightage']
      @ec_weightage = params['ecWeightage']
    end
    if params['save']
      @questionnaire.update_attributes(params[:questionnaire])
      save_questionnaire  
    end
    
    if params['export']
      csv_data = QuestionnaireHelper::create_questionnaire_csv @questionnaire, session[:user].name

      send_data csv_data, 
        :type => 'text/csv; charset=iso-8859-1; header=present',
        :disposition => "attachment; filename=questionnaires.csv"
    end
    
    if params['import']
      file = params['csv']
      questions = QuestionnaireHelper::get_questions_from_csv(@questionnaire, file)
      
      if questions != nil and questions.length > 0

        # delete the existing questions if no scores have been recorded yet
        @questionnaire.questions.each {
          | question |
            raise "Cannot import new questions, scores exist" if Score.find_by_question_id(question.id)
            question.delete        
        }
        
        @questionnaire.questions = questions
      end
    end
    
    if params['view_advice']
        redirect_to :action => 'edit_advice', :id => params[:questionnaire][:id]
    end
    rescue
      flash[:error] = $!
    end

    get_extra_credit_questions # This should be here.
  end
    
  # Define a new questionnaire
  def new
    @questionnaire = Object.const_get(params[:model]).new
    @questionnaire.private = params[:private] 
    @questionnaire.min_question_score = Questionnaire::DEFAULT_MIN_QUESTION_SCORE
    @questionnaire.max_question_score = Questionnaire::DEFAULT_MAX_QUESTION_SCORE    
  end

  # Save the new questionnaire to the database
  def create_questionnaire
    @questionnaire = Object.const_get(params[:questionnaire][:type]).new(params[:questionnaire])

    if (session[:user]).role.name == "Teaching Assistant"
      @questionnaire.instructor_id = Ta.get_my_instructor((session[:user]).id)
    else
      @questionnaire.instructor_id = session[:user].id
    end       
    save_questionnaire    
    redirect_to :controller => 'tree_display', :action => 'list'
  end
  
  # Modify the advice associated with a questionnaire
  def edit_advice
    @questionnaire = get(Questionnaire, params[:id])
    
    for question in @questionnaire.questions
      if question.true_false
        num_questions = 2
      else
        num_questions = @questionnaire.max_question_score - @questionnaire.min_question_score
      end
      
      sorted_advice = question.question_advices.sort {|x,y| y.score <=> x.score } 
      if question.question_advices.length != num_questions or
         sorted_advice[0].score != @questionnaire.min_question_score or
         sorted_advice[sorted_advice.length-1] != @questionnaire.max_question_score
        #  The number of advices for this question has changed.
        QuestionnaireHelper::adjust_advice_size(@questionnaire, question)
      end
    end
    @questionnaire = get(Questionnaire, params[:id])
  end
  
  # save the advice for a questionnaire
  def save_advice
    begin
      for advice_key in params[:advice].keys
        QuestionAdvice.update(advice_key, params[:advice][advice_key])
      end
      flash[:notice] = "The questionnaire's question advice was successfully saved"
      redirect_to :action => 'list'
      
    rescue ActiveRecord::RecordNotFound
      render :action => 'edit_advice'
    end
  end
  
  private  
  #save questionnaire object after create or edit
  def save_questionnaire     
    begin
      @questionnaire.save!
      save_questions @questionnaire.id if @questionnaire.id != nil and @questionnaire.id > 0

      # Check if the questionnaire has got questions of extra credit section after this save action.
      # If it does, then add a row for this questionnaire in sections table, only if it is not present.
      glist1 = Question.find_all_by_questionnaire_id(@questionnaire.id)
      temp = 0
      glist2 = Question.find_all_by_questionnaire_id_and_section(@questionnaire.id, temp)
      if glist1.length != glist2.length
        glist3 = Section.find_all_by_questionnaire_id(@questionnaire.id)
        if glist3.blank?
          s = Section.new
          s.questionnaire_id = @questionnaire.id
          s.is_extra_credit=true
          if !@ec_weightage.nil?
           s.extra_credit_weightage=@ec_weightage
          else
            s.extra_credit_weightage=10
          end
          s.save!
        end
      end

      pFolder = TreeFolder.find_by_name(@questionnaire.display_type)
      parent = FolderNode.find_by_node_object_id(pFolder.id)
      if QuestionnaireNode.find_by_parent_id_and_node_object_id(parent.id,@questionnaire.id) == nil
        QuestionnaireNode.create(:parent_id => parent.id, :node_object_id => @questionnaire.id)
      end

    rescue
      flash[:error] = $!
    end
  end
  
  
  # save questions that have been added to a questionnaire
  def save_new_questions(questionnaire_id)
    if params[:new_question]
      # The new_question array contains all the new questions
      # that should be saved to the database
      for question_key in params[:new_question].keys
        q = Question.new(params[:new_question][question_key])
        q.questionnaire_id = questionnaire_id
        q.save if !q.txt.strip.empty?
      end
    end
  end
  
  # delete questions from a questionnaire
  def delete_questions(questionnaire_id)
    # Deletes any questions that, as a result of the edit, are no longer in the questionnaire
    questions = Question.find(:all, :conditions => "questionnaire_id = " + questionnaire_id.to_s)
    for question in questions
      should_delete = true
      for question_key in params[:question].keys
        if question_key.to_s === question.id.to_s
          should_delete = false
        end
      end
      
      if should_delete == true
        for advice in question.question_advices
          advice.destroy
        end
        question.destroy
      end
    end
  end

  def delete_sections(questionnaire_id)
    glist1 = Question.find_all_by_questionnaire_id(questionnaire_id)
    temp = 0
    glist2 = Question.find_all_by_questionnaire_id_and_section(questionnaire_id, temp)
    if glist1.length == glist2.length
       temp = Section.find_all_by_questionnaire_id(questionnaire_id)
       if !temp.blank?
         for i in temp do
           i.delete
         end
       end
    end
  end

  # Handles questions whose wording changed as a result of the edit    
  def save_questions(questionnaire_id)
    delete_questions questionnaire_id
    delete_sections questionnaire_id
    save_new_questions questionnaire_id
    
    if params[:question]
      for question_key in params[:question].keys
        begin
          if params[:question][question_key][:txt].strip.empty?
            # question text is empty, delete the question
            Question.delete(question_key)
          else
            # Update existing question.
            Question.update(question_key, params[:question][question_key])
          end
        rescue ActiveRecord::RecordNotFound 
        end
      end
    end
  end

  def get_extra_credit_questions()
    @ec_questions = Question.find(:all, :conditions => "questionnaire_id = " + params[:id].to_s + " and section = 1")
    # @questionnaire.ec_questions = ec_questions
  end

  def save_weightage id
    w = Section.find_by_questionnaire_id(id)
    w.extra_credit_weightage = params[:section][:extra_credit_weightage]
    w.save!
    @weightage = w
  end

end