require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodSourceInstaller do

    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      specs_by_platform = { :ios => [@spec] }
      @installer = Installer::PodSourceInstaller.new(config.sandbox, specs_by_platform)
    end

    #-------------------------------------------------------------------------#

    describe "In General" do

      it "doesn't use an aggressive cache by default" do
        @installer.should.not.aggressive_cache?
      end

    end

    #-------------------------------------------------------------------------#

    describe "Installation" do

      describe "Download" do
        it "downloads the source" do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source.should.be.nil
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it "downloads the head source if specified source" do
          @spec.version.head = true
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source[:commit].should == "0b8b4084a43c38cfe308efa076fdeb3a64d9d2bc"
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it "returns the checkout options of the downloader if any" do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :branch => 'topicbranch' }
          @installer.install!
          @installer.specific_source[:commit].should == "446b22414597f1bb4062a62c4eed7af9627a3f1b"
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it "stores the checkout options in the sandbox" do
          @spec.version.head = true
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          sources = @installer.sandbox.checkout_sources
          sources.should == { "BananaLib" => {
            :git => SpecHelper.fixture('banana-lib'),
            :commit=>"0b8b4084a43c38cfe308efa076fdeb3a64d9d2bc" }
          }
        end

      end

      #--------------------------------------#

      describe "Cleaning" do

        it "cleans the paths non used by the installation" do
          @installer.install!
          @installer.clean!
          unused_file = config.sandbox.root + 'Sources/BananaLib/sub-dir/sub-dir-2/somefile.txt'
          unused_file.should.not.exist
        end

        it "preserves important files like the LICENSE and the README" do
          @installer.install!
          @installer.clean!
          readme_file = config.sandbox.root + 'Sources/BananaLib/README'
          readme_file.should.exist
        end

      end

      #--------------------------------------#

      describe "Options" do

        it "doesn't downloads the source if the pod was already downloaded" do
          @installer.stubs(:predownloaded?).returns(true)
          @installer.expects(:download_source).never
          @installer.stubs(:clean_installation)
          @installer.install!
        end

        it "doesn't downloads the source if the pod has a local source" do
          config.sandbox.store_local_path('BananaLib', 'Some Path')
          @installer.expects(:download_source).never
          @installer.install!
        end

        it "doesn't clean the installation if the pod has a local source" do
          config.sandbox.store_local_path('BananaLib', 'Some Path')
          @installer.expects(:clean_installation).never
          @installer.install!
        end

      end

      #--------------------------------------#

    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      it "returns the clean paths" do
        @installer.send(:download_source)
        paths = @installer.send(:clean_paths)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '')}
        paths_without_git = relative_paths.reject { |p| p.include? 'Pods/Sources/BananaLib/.git' }
        paths_without_git.sort.should == [
          "Pods/Sources/BananaLib/BananaLib.podspec",
          "Pods/Sources/BananaLib/libPusher",
          "Pods/Sources/BananaLib/sub-dir",
          "Pods/Sources/BananaLib/sub-dir/sub-dir-2",
          "Pods/Sources/BananaLib/sub-dir/sub-dir-2/somefile.txt"
        ]
      end

      it "returns the used files" do
        @installer.send(:download_source)
        paths = @installer.send(:used_files)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '')}
        relative_paths.sort.should == [
          "Pods/Sources/BananaLib/Classes/Banana.h",
          "Pods/Sources/BananaLib/Classes/Banana.m",
          "Pods/Sources/BananaLib/Classes/BananaLib.pch",
          "Pods/Sources/BananaLib/Classes/BananaPrivate.h",
          "Pods/Sources/BananaLib/LICENSE",
          "Pods/Sources/BananaLib/README",
          "Pods/Sources/BananaLib/Resources/logo-sidebar.png"
        ]
      end

      it "handles Pods with multiple file accessors" do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        spec.source = { :git => SpecHelper.fixture('banana-lib') }
        spec.source_files = []
        spec.ios.source_files = 'Classes/*.h'
        spec.osx.source_files = 'Classes/*.m'
        ios_spec = spec.dup
        osx_spec = spec.dup
        specs_by_platform = { :ios => [ios_spec], :osx => [osx_spec] }
        @installer = Installer::PodSourceInstaller.new(config.sandbox, specs_by_platform)
        @installer.send(:download_source)
        paths = @installer.send(:used_files)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '')}
        relative_paths.sort.should == [
          "Pods/Sources/BananaLib/Classes/Banana.h",
          "Pods/Sources/BananaLib/Classes/Banana.m",
          "Pods/Sources/BananaLib/Classes/BananaLib.pch",
          "Pods/Sources/BananaLib/Classes/BananaPrivate.h",
          "Pods/Sources/BananaLib/LICENSE",
          "Pods/Sources/BananaLib/README",
          "Pods/Sources/BananaLib/Resources/logo-sidebar.png"
        ]
      end

      it "compacts the used files as nil would be converted to the empty string" do
        Sandbox::FileAccessor.any_instance.stubs(:source_files)
        Sandbox::FileAccessor.any_instance.stubs(:resources).returns(nil)
        Sandbox::FileAccessor.any_instance.stubs(:preserve_paths)
        Sandbox::FileAccessor.any_instance.stubs(:prefix_header)
        Sandbox::FileAccessor.any_instance.stubs(:readme)
        Sandbox::FileAccessor.any_instance.stubs(:license)
        paths = @installer.send(:used_files)
        paths.should == []
      end

    end

    #-------------------------------------------------------------------------#

  end
end
