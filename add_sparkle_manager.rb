require 'xcodeproj'

project = Xcodeproj::Project.open('Glide.xcodeproj')
app_target = project.targets.find { |t| t.name == 'Glide' }
group = project.main_group.find_subpath('Glide', true)

file_ref = group.find_file_by_path('SparkleManager.swift') || group.new_file('SparkleManager.swift')

if !app_target.source_build_phase.files_references.include?(file_ref)
  app_target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "Successfully added SparkleManager.swift"
