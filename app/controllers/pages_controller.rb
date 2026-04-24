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
      unit: params[:unit]
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
    
    # 2. Build Paper header
    @paper = Paper.new(
      title: params[:title],
      subject: @subject
    )

    if @paper.save
      # 3. THE SHUFFLE ALGORITHM:
      # Separate sessions for each difficulty to ensure exact selection
      diff_counts = {
        'Easy'   => params[:easy_count].to_i,
        'Medium' => params[:medium_count].to_i,
        'Hard'   => params[:hard_count].to_i
      }

      has_questions = false

      diff_counts.each do |diff, count|
        next if count <= 0
        
        # Shuffle and pick the limit for this specific difficulty bucket
        questions = @subject.questions.where(difficulty: diff).order("RANDOM()").limit(count)
        
        questions.each do |q|
          PaperQuestion.create!(paper: @paper, question: q)
          has_questions = true
        end
      end

      if has_questions
        redirect_to view_paper_path(id: @paper.id)
      else
        @paper.destroy # Cleanup if no questions were added
        redirect_to pages_generate_paper_path, alert: "Algorithm failed: No questions found for the selected counts."
      end
    else
      redirect_to pages_generate_paper_path, alert: "Failed to generate paper."
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

  def edit_subject
  @subject = Subject.find(params[:id])
end

def update_subject
  @subject = Subject.find(params[:id])
  if @subject.update(name: params[:name], code: params[:code])
    redirect_to pages_manage_subjects_path, notice: "Subject updated successfully!"
  else
    render :edit_subject, alert: "Failed to update subject."
  end
end

def edit_question
  @question = Question.find(params[:id])
  @subjects = Subject.all
end

def update_question
  @question = Question.find(params[:id])
  if @question.update(content: params[:content], difficulty: params[:difficulty], unit: params[:unit], subject_id: params[:subject_id])
    redirect_to pages_question_bank_path, notice: "Question updated successfully!"
  else
    redirect_to edit_question_path(@question), alert: "Failed to update question."
  end
end

def delete_question
  @question = Question.find(params[:id])
  @question.destroy
  redirect_to pages_question_bank_path, notice: "Question deleted successfully."
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