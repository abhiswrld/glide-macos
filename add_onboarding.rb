require 'xcodeproj'

project = Xcodeproj::Project.open('Glide.xcodeproj')
app_target = project.targets.find { |t| t.name == 'Glide' }

file_path = 'Glide/OnboardingView.swift'
unless project.main_group.find_file_by_path(file_path)
  # Find or create a group
  group = project.main_group.find_subpath('Glide', true)
  file_ref = group.new_file('OnboardingView.swift')
  app_target.source_build_phase.add_file_reference(file_ref)
  project.save
  puts "Added OnboardingView.swift"
else
  puts "Already exists"
end
