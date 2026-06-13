class CourseTrainerMailer < ApplicationMailer
  def assigned_to_course(trainer, course)
    @trainer = trainer
    @course  = course
    mail(to: trainer.user.email,
         subject: "Du wurdest dem Kurs „#{course.title}“ als Leiter zugeteilt")
  end
end
