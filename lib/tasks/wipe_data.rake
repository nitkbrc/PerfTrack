namespace :db do
  desc "Wipe users and all dependent data (local dev reset before profile migration)"
  task wipe_user_data: :environment do
    puts "Wiping achievement requests, notifications, and history..."
    Notification.delete_all
    ReqHistory.delete_all
    AchievementRequest.find_each(&:destroy!)

    puts "Wiping division tree..."
    Category.delete_all
    SubDivision.delete_all
    Division.delete_all

    puts "Wiping students and users..."
    Student.delete_all
    User.find_each(&:destroy!)

    puts "Wiping departments and reason templates..."
    Department.delete_all
    ReasonTemplateSuppression.delete_all
    ReasonTemplate.delete_all

    puts "Done — run db:migrate (if needed) and db:seed."
  end
end
