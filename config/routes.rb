Rails.application.routes.draw do
  # Authentication
  get "pages/register"
  post "pages/register", to: "users#create"
  get "pages/login"
  post "pages/login", to: "sessions#create"
  root "pages#login"
  delete "logout", to: "sessions#destroy", as: :logout
  
  # Core Dashboard & Pages
  get "pages/dashboard", as: :pages_dashboard
  get "pages/manage_subjects", as: :pages_manage_subjects
  get "pages/question_bank", as: :pages_question_bank
  get "pages/generate_paper", as: :pages_generate_paper
  get "pages/generated_papers", as: :pages_generated_papers
  
  # Paper View & Management
  get "pages/view_paper", to: "pages#view_paper", as: :view_paper
  post "create_paper", to: "pages#create_paper", as: :create_paper
  delete "delete_paper/:id", to: "pages#delete_paper", as: :delete_paper
get  'edit_subject/:id', to: 'pages#edit_subject', as: :edit_subject
patch 'update_subject/:id', to: 'pages#update_subject', as: :update_subject
  # Subject Management
  post "add_subject", to: "pages#add_subject", as: :add_subject

  
get    'edit_question/:id', to: 'pages#edit_question', as: :edit_question
patch  'update_question/:id', to: 'pages#update_question', as: :update_question
delete 'delete_question/:id', to: 'pages#delete_question', as: :delete_question

  # --- CSV IMPORT SECTION (FIXED) ---
  # The GET route for the upload screen
  get "import_questions_page", to: "pages#import_questions_page", as: :import_questions_page
  post "add_question", to: "pages#add_question", as: :add_question
  # The POST route for the actual upload action
  post "import_questions", to: "pages#import_questions", as: :import_questions
  # ----------------------------------

  # Health Check
  get "up" => "rails/health#show", as: :rails_health_check
end