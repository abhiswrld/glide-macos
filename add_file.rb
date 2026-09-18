require 'xcodeproj'
project_path = 'Glide.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the file to the Glide group
group = project.main_group.find_subpath('Glide', false)
file_ref = group.new_file('SmartChargingModel.swift')

# Add the file to the compile sources phase
target.source_build_phase.add_file_reference(file_ref)

project.save
