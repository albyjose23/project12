require 'csv'

class PagesController < ApplicationController
  before_action :authenticate_user!, except: [ :login, :register ]
  before_action :redirect_if_authenticated, only: [ :login, :register ]

  def login; end
  def register; end

  def dashboard
    @total_papers = Paper.count
    @total_questions = Question.count
    @total_subjects = Subject.count
    @recent_papers = Paper.includes(:subject).order(created_at: :desc).limit(5)
  end

  def manage_subjects
    @subjects = Subject.all.order(code: :asc)
  end

  def add_subject
    @subject = Subject.new(name: params[:name], code: params[:code])
    if @subject.save
      redirect_to pages_manage_subjects_path, notice: "Subject created!"
    else
      redirect_to pages_manage_subjects_path, alert: "Failed to create subject."
    end
  end

  def add_question
    @question = Question.new(
      content: params[:content],
      difficulty: params[:difficulty],
      subject_id: params[:subject_id],
      unit: params[:unit] # Added unit support
    )
    
    if @question.save
      redirect_to pages_question_bank_path, notice: "Question saved!"
    else
      redirect_to pages_question_bank_path, alert: "Error: #{@question.errors.full_messages.join(', ')}"
    end
  end

  def import_questions_page; end

  def delete_paper
    @paper = Paper.find(params[:id])
    @paper.destroy
    redirect_to pages_generated_papers_path, notice: "Paper deleted successfully."
  end

  def create_paper
    # 1. Find Subject
    @subject = Subject.find(params[:subject_id])
    
    # 2. Build Paper (FIXED: Removed unknown exam_type attribute)
    @paper = Paper.new(
      title: params[:title],
      # exam_type removed because it's not in your database table yet
      subject: @subject
    )

    if @paper.save
      # 3. THE RANDOMIZER: 
      # Fetching questions based on user-defined limits
      easy_qs   = @subject.questions.where(difficulty: 'Easy').order("RANDOM()").limit(params[:easy_count].to_i)
      medium_qs = @subject.questions.where(difficulty: 'Medium').order("RANDOM()").limit(params[:medium_count].to_i)
      hard_qs   = @subject.questions.where(difficulty: 'Hard').order("RANDOM()").limit(params[:hard_count].to_i)

      all_selected = [easy_qs, medium_qs, hard_qs].flatten

      if all_selected.any?
        # 4. Link questions to the paper using the join table
        all_selected.each do |q|
          PaperQuestion.create!(paper: @paper, question: q)
        end
        redirect_to view_paper_path(id: @paper.id)
      else
        @paper.destroy # Cleanup empty paper
        redirect_to pages_generate_paper_path, alert: "No questions found for the selected subject/difficulty."
      end
    else
      redirect_to pages_generate_paper_path, alert: "Failed to generate paper header."
    end
  end

  def import_questions
    file = params[:file]
    subject = Subject.find(params[:subject_id])

    if file.present?
      begin
        CSV.foreach(file.path, headers: true) do |row|
          Question.create!(
            content: row['content'],
            difficulty: row['difficulty'],
            unit: row['unit'], 
            subject: subject
          )
        end
        redirect_to pages_question_bank_path, notice: "Questions imported successfully!"
      rescue => e
        redirect_to pages_question_bank_path, alert: "CSV Error: #{e.message}"
      end
    else
      redirect_to pages_question_bank_path, alert: "Please upload a valid CSV file."
    end
  end

  def generate_paper; end

  def generated_papers
    @papers = Paper.includes(:subject).order(created_at: :desc)
  end

  def view_paper
    @paper = Paper.find(params[:id])
  end

  private

  def redirect_if_authenticated
    redirect_to pages_dashboard_path if user_signed_in?
  end
end