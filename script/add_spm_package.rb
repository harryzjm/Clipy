#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds the Swift Package Manager dependencies the app target needs, idempotently.
#
# CocoaPods owns `Clipy.xcworkspace`, but it never reads or writes the SPM objects in
# `Clipy.xcodeproj` — so the two coexist and `pod install` leaves these entries alone.
# Editing the pbxproj through the `xcodeproj` gem (already pinned by `Gemfile.lock`, because
# CocoaPods depends on it) rather than by hand keeps `objectVersion = 77` and the
# `PBXFileSystemSynchronizedRootGroup` entries intact.
#
#   bundle exec ruby script/add_spm_package.rb

require 'xcodeproj'

O = Xcodeproj::Project::Object

PROJECT_PATH = File.expand_path('../Clipy.xcodeproj', __dir__)
TARGET_NAME = 'Clipy'

# Only the app target links these. `ClipyTests` inherits search paths and loads the host
# process, so it sees the symbols without a dependency of its own.
PACKAGES = [
  {
    url: 'https://github.com/CodeEditApp/CodeEditSourceEditor',
    # Pinned exactly: 0.14.0 renamed the whole public API, and `CodeEditLanguages` is pinned
    # to an exact version upstream anyway.
    requirement: { 'kind' => 'exactVersion', 'version' => '0.15.2' },
    products: %w[CodeEditSourceEditor]
  }
].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)

target = project.targets.find { |t| t.name == TARGET_NAME }
raise "target #{TARGET_NAME} not found" unless target
raise "#{TARGET_NAME} is not an app target" unless target.product_type == 'com.apple.product-type.application'

def normalized(url)
  url.to_s.sub(/\.git\z/, '')
end

PACKAGES.each do |spec|
  reference = project.root_object.package_references.find do |ref|
    ref.is_a?(O::XCRemoteSwiftPackageReference) && normalized(ref.repositoryURL) == normalized(spec[:url])
  end

  unless reference
    reference = project.new(O::XCRemoteSwiftPackageReference)
    reference.repositoryURL = spec[:url]
    project.root_object.package_references << reference
  end
  # Re-assigned every run, so bumping the version above is all a version bump takes.
  reference.requirement = spec[:requirement]

  spec[:products].each do |product_name|
    dependency = target.package_product_dependencies.find { |dep| dep.product_name == product_name }

    unless dependency
      dependency = project.new(O::XCSwiftPackageProductDependency)
      dependency.product_name = product_name
      target.package_product_dependencies << dependency
    end
    dependency.package = reference

    # `add_file_reference` type-checks its argument against PBXFileReference and friends, so a
    # product dependency has to be wired up by hand. The build file must be parented before
    # `save`, or serializing its annotation raises on a node with no parent.
    phase = target.frameworks_build_phase
    next if phase.files.any? { |file| file.product_ref == dependency }

    build_file = project.new(O::PBXBuildFile)
    build_file.product_ref = dependency
    phase.files << build_file
  end
end

project.save

puts "packages: #{project.root_object.package_references.map { |r| "#{r.repositoryURL} #{r.requirement}" }}"
project.targets.each do |t|
  puts "#{t.name}: #{t.package_product_dependencies.map(&:product_name)}"
end
