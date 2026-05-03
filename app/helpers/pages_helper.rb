module PagesHelper
  def paper_section_total(question_count, marks)
    question_count.to_i * marks.to_i
  end

  def paper_section_distribution(question_count, marks)
    "(#{question_count} X #{marks} = #{paper_section_total(question_count, marks)} Marks)"
  end

  def paper_question_text(question)
    question.content.to_s.gsub(/\s*\[\d+\]\s*$/, "").strip
  end

  def paper_duration_text(paper)
    paper.duration.presence || "3 Hrs"
  end

  def paper_total_marks_text(paper)
    paper.total_marks.presence || paper.questions.sum(&:display_marks)
  end
end
