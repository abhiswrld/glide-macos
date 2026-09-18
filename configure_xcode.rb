require 'xcodeproj'

project = Xcodeproj::Project.open('Glide.xcodeproj')
app_target = project.targets.find { |t| t.name == 'Glide' }
daemon_target = project.targets.find { |t| t.name == 'glide-daemon' }

# Add target dependency
unless app_target.dependencies.any? { |dep| dep.target == daemon_target }
  app_target.add_dependency(daemon_target)
end

# 1. Embed daemon executable
unless app_target.copy_files_build_phases.any? { |p| p.name == 'Embed Daemon' }
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed Daemon'
  embed_phase.symbol_dst_subfolder_spec = :executables # Copies to Contents/MacOS
  app_target.build_phases << embed_phase

  # The product reference of glide-daemon
  daemon_ref = daemon_target.product_reference
  build_file = embed_phase.add_file_reference(daemon_ref)
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
end

# 2. Embed plist
plist_path = 'glide-daemon/com.abhinav.glide-daemon.plist'
plist_ref = project.main_group.find_file_by_path(plist_path) || project.main_group.new_file(plist_path)

unless app_target.copy_files_build_phases.any? { |p| p.name == 'Embed Daemon Plist' }
  plist_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  plist_phase.name = 'Embed Daemon Plist'
  plist_phase.symbol_dst_subfolder_spec = :wrapper # Copies to root of bundle (Contents for Mac)
  plist_phase.dst_path = 'Contents/Library/LaunchDaemons'
  app_target.build_phases << plist_phase

  plist_phase.add_file_reference(plist_ref)
end

project.save
puts "Successfully configured Xcode project!"
