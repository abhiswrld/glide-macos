require 'xcodeproj'

project = Xcodeproj::Project.open('Glide.xcodeproj')
app_target = project.targets.find { |t| t.name == 'Glide' }

pkg_ref = project.root_object.package_references.find { |pr| pr.respond_to?(:repositoryURL) && pr.repositoryURL == 'https://github.com/sparkle-project/Sparkle' }
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = 'https://github.com/sparkle-project/Sparkle'
  pkg_ref.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => '2.6.2'
  }
  project.root_object.package_references << pkg_ref
end

pkg_dep = app_target.package_product_dependencies.find { |pd| pd.product_name == 'Sparkle' }
unless pkg_dep
  pkg_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  pkg_dep.product_name = 'Sparkle'
  pkg_dep.package = pkg_ref
  app_target.package_product_dependencies << pkg_dep
end

project.save
puts "Successfully added Sparkle package dependency"
