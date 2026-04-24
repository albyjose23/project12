class PaperQuestion < ApplicationRecord
  belongs_to :paper
  belongs_to :question
end